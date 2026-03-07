# Auth Mail Resend State Machine v1

## 목적

회원가입 확인 메일, 비밀번호 재설정 메일, 이메일 변경 확인 메일을 같은 UX 축으로 다루되,
액션 타입이 서로 다른 흐름을 잘못 막지 않도록 액션별 resend 상태 기계를 고정합니다.

## 액션 키

메일 액션 key는 아래 조합으로 분리합니다.

- `actionType`
  - `signup_confirmation`
  - `password_reset`
  - `email_change`
- `recipient`
  - 정규화한 대상 이메일
- `context`
  - 현재는 `signup_sheet`
  - 같은 액션이라도 표면이 달라지면 별도 문맥으로 분리 가능

예:

- `signup_confirmation::hello@dogarea.test::signup_sheet`
- `password_reset::hello@dogarea.test::reset_sheet`
- `email_change::next@dogarea.test::settings_email_change`

## 상태 모델

필수 상태는 아래 6개입니다.

- `idle`
- `sending`
- `sent`
- `cooldown`
- `rate_limited`
- `failed`

### 의미

- `idle`: 지금 요청을 보낼 수 있음
- `sending`: 동일 액션 중복 탭 금지
- `sent`: 방금 서버 성공 응답을 받았고 성공 배너를 짧게 유지하는 구간
- `cooldown`: 성공 직후 재전송을 잠시 막는 구간
- `rate_limited`: `429` 또는 `Retry-After`로 서버가 명시적으로 막은 구간
- `failed`: 네트워크/기타 실패. 다음 시도는 허용하지만 실패 문구를 남김

## 상태 유지 범위

- `sending`
  - view-local only
  - 화면 재진입 시 복원하지 않음
- `failed`
  - view-local only
  - 사용자가 다시 시도하면 덮어씀
- `sent / cooldown / rate_limited`
  - `UserDefaults` snapshot으로 유지
  - 시트 dismiss / reopen, 화면 이동 후 복귀에도 유지

## Stale Tolerance / Refresh 규칙

canonical source는 서버 응답입니다.

앱은 서버 응답 이후 아래 snapshot만 로컬에 유지합니다.

- `sentBannerUntil`
- `nextAllowedAt`
- `retryAfterSeconds`
- `wasRateLimited`

refresh rule:

1. 현재 시각 `< sentBannerUntil` 이면 `sent`
2. 현재 시각 `>= sentBannerUntil` 이고 `< nextAllowedAt` 이면
   - `wasRateLimited == true` -> `rate_limited`
   - 그 외 -> `cooldown`
3. 현재 시각 `>= nextAllowedAt` 이면 snapshot 제거 후 `idle`

## Retry-After 우선순위

1. 서버 `Retry-After`
2. 액션별 fallback cooldown

현재 fallback 값:

- signup confirmation: `60s`
- password reset: `75s`
- email change: `90s`

## 현재 앱 적용 범위

이번 사이클에서 실제 UI에 붙인 표면은 `signup_sheet` 입니다.

- 초기 회원가입 성공 후 즉시 dismiss 하지 않음
- 성공 카드에서 `프로필 입력 계속`과 `인증 메일 다시 보내기`를 함께 제공
- cooldown/rate-limited 상태에서는 resend 버튼 disabled
- 남은 시간 문구를 버튼과 카드 설명에 함께 표시

reset / email change는 아직 표면이 없으므로,
이번 사이클에서는 **상태 모델 / key 분리 / 저장소 계약**까지만 선반영합니다.

## 사용자 문구 원칙

- 내부 운영 용어 금지
- `SMTP`, `Rate Limit`, `over_email_send_rate_limit` 노출 금지
- 사용자 관점 행동만 안내

예:

- `요청이 많아 잠시 기다린 뒤 다시 보낼 수 있어요. 48초 후 다시 시도해주세요.`
- `방금 메일을 보냈어요. 31초 후 다시 보낼 수 있어요.`

## 관측성

metric/log payload:

- `action_type`
- `surface`
- `retry_after_seconds`
- `duplicate_suppressed`

metric event:

- `auth_mail_action_succeeded`
- `auth_mail_action_rate_limited`
- `auth_mail_action_failed`
- `auth_mail_action_suppressed`

## QA 시나리오

1. signup 성공
- 성공 카드 노출
- `프로필 입력 계속`으로 온보딩 진입 가능
- resend 버튼이 바로 연속 탭되지 않음

2. signup `429`
- `Retry-After`가 있으면 그 초 단위가 우선 반영됨
- 없으면 `60s` fallback 사용
- 버튼 disabled + 남은 시간 노출

3. 네트워크 실패
- resend 상태는 `failed`
- 사용자는 즉시 다시 시도 가능

4. 중복 탭
- `sending` 중 추가 탭 억제
- metric/log에 `duplicate_suppressed=true`

5. sheet dismiss / reopen
- `sent / cooldown / rate_limited` snapshot 유지
- 입력 이메일이 같으면 같은 상태가 다시 보임

6. background 복귀
- 현재 시각 기준으로 상태 재해석
- `nextAllowedAt`이 지났으면 자동으로 `idle` 복귀
