# Auth Mail Cooldown / Retry-After UX v1

Date: 2026-03-08  
Issue: #483

## 목적

DogArea iOS에서 auth mail 액션을 연속 탭으로 남발하지 못하게 하고,
`429` / `Retry-After` 상황에서 사용자가 다음 행동을 명확히 이해하도록 UX 계약을 고정합니다.

이 문서는 아래를 함께 정리합니다.

- action별 resend / cooldown 정책
- `Retry-After` 우선순위
- duplicate tap / duplicate request suppression 규칙
- 사용자용 문구 원칙
- metric / log 기준
- QA 시나리오

## 범위

포함:

- signup confirmation resend
- password reset mail send
- email change confirmation mail send
- `429 + Retry-After` 처리
- duplicate suppression / local state persistence

제외:

- SMTP provider 교체
- auth abuse 정책 자체 변경
- 회원가입 UI 전면 리디자인

## 현재 구현 기준

현재 저장소 기준 canonical 구현은 아래입니다.

- 상태 타입 / fallback cooldown / 사용자 문구
  - `dogArea/Source/Domain/Auth/Models/AuthMailActionModels.swift`
- 상태기계 / snapshot persistence
  - `dogArea/Source/Domain/Auth/Services/AuthMailActionStateMachine.swift`
  - `dogArea/Source/UserDefaultsSupport/AuthMailActionStateStore.swift`
- server dispatch / `Retry-After` 해석 / 429 정규화
  - `dogArea/Source/Infrastructure/Supabase/Services/SupabaseAuthMailActionService.swift`
- 현재 live surface
  - `dogArea/Views/SigningView/Components/EmailSignUpSheetView.swift`

중요:

- 지금 실제 UI가 붙은 표면은 `signup_sheet` 입니다.
- 하지만 action key / fallback cooldown / `Retry-After` / metric payload는
  `signup_confirmation`, `password_reset`, `email_change` 3개를 모두 지원하도록 이미 분리되어 있습니다.
- 이후 reset / email change UI surface를 추가할 때도 이 문서의 계약을 그대로 재사용합니다.

## 액션별 cooldown 정책

| 액션 | action key | surface 예시 | fallback cooldown | resend 버튼 문구 |
| --- | --- | --- | --- | --- |
| 회원가입 확인 메일 | `signup_confirmation::<email>::signup_sheet` | `signup_sheet` | `60s` | `인증 메일 다시 보내기` |
| 비밀번호 재설정 메일 | `password_reset::<email>::reset_sheet` | `password_reset_sheet` | `75s` | `재설정 메일 다시 보내기` |
| 이메일 변경 확인 메일 | `email_change::<email>::settings_email_change` | `settings_email_change` | `90s` | `변경 확인 메일 다시 보내기` |

원칙:

- action key는 `actionType + normalized email + surface context` 조합으로 분리합니다.
- signup / reset / email change는 하나의 global lock으로 막지 않습니다.
- 한 액션의 rate limit이나 cooldown이 다른 액션 흐름을 잘못 막으면 안 됩니다.

## 상태 모델

필수 상태:

- `idle`
- `sending`
- `sent`
- `cooldown`
- `rate_limited`
- `failed`

의미:

- `idle`: 요청 가능
- `sending`: 요청 진행 중, 중복 탭 금지
- `sent`: 서버 성공 직후 성공 배너 유지
- `cooldown`: 성공 후 잠시 재요청 금지
- `rate_limited`: 서버 `429` / `Retry-After`에 의해 차단
- `failed`: 네트워크 또는 기타 실패, 즉시 재시도 가능

## Duplicate Tap / Duplicate Request Guard

중복 탭 방지 규칙:

1. `loading == true` 또는 `isMailActionDispatching == true`이면 즉시 억제합니다.
2. 상태기계가 `isRequestAllowed == false`이면 억제합니다.
3. 억제된 경우 사용자 메시지를 즉시 갱신하고 `duplicate_suppressed=true`를 metric으로 남깁니다.
4. `sending` / `sent` / `cooldown` / `rate_limited` 상태에서는 버튼을 다시 활성화하지 않습니다.

지속성 규칙:

- `sending`: view-local only
- `failed`: view-local only
- `sent / cooldown / rate_limited`: `UserDefaults` snapshot 유지
- 따라서 view dismiss / reopen, background 복귀 후에도 guard가 쉽게 풀리지 않습니다.

## Retry-After 우선순위

우선순위는 아래와 같습니다.

1. 서버 응답 `Retry-After`
2. action별 fallback cooldown

해석 규칙:

- `SupabaseAuthMailActionService`가 HTTP 응답의 `Retry-After`를 초 단위로 읽습니다.
- `429`에서 `Retry-After`가 있으면 그 값을 `rate_limited` 상태에 우선 반영합니다.
- `Retry-After`가 없으면 action별 fallback cooldown을 사용합니다.

사용자에게 보이는 문구 예:

- `요청이 많아 잠시 기다린 뒤 다시 보낼 수 있어요. 48초 후 다시 시도해주세요.`
- `방금 메일을 보냈어요. 31초 후 다시 보낼 수 있어요.`

## 낙관적 전송 금지

금지:

- 버튼 탭 직후 서버 응답 전에 `전송 완료` 표시
- 실제 실패인데도 성공 상태 유지

허용:

- 실제 서버 `2xx` 응답을 받은 뒤에만 `sent` 상태 진입
- `429`이면 `rate_limited`
- 기타 실패면 `failed`

즉, canonical source는 서버 응답입니다.

## 사용자 문구 원칙

금지:

- `SMTP`
- `Rate Limit`
- `over_email_send_rate_limit`
- `endpoint 설정 확인`
- 기타 운영자 내부 용어

허용:

- 지금 왜 다시 못 누르는지
- 몇 초 후 다시 가능한지
- 메일함에서 어떤 행동을 해야 하는지

액션별 성공 문구:

- signup: `인증 메일을 보냈어요` / `<email> 메일함을 확인한 뒤 프로필 입력을 계속하세요.`
- reset: `재설정 메일을 보냈어요` / `<email> 메일함에서 비밀번호 재설정 링크를 확인하세요.`
- email change: `변경 확인 메일을 보냈어요` / `<email> 메일함에서 이메일 변경 확인 링크를 확인하세요.`

## Metric / Log 기준

필수 payload:

- `action_type`
- `surface`
- `retry_after_seconds`
- `duplicate_suppressed`

canonical event:

- `auth_mail_action_succeeded`
- `auth_mail_action_rate_limited`
- `auth_mail_action_failed`
- `auth_mail_action_suppressed`

로그 기준:

- 사용자 문구와 운영 로그를 분리합니다.
- DEBUG 로그나 metric에는 `retry_after_seconds`, `surface`, `action_type`를 남깁니다.
- 사용자에게는 남은 시간과 다음 행동만 보여줍니다.

## QA 시나리오

### 1. signup 성공

- 성공 카드가 노출되어야 함
- `프로필 입력 계속`으로 온보딩을 이어갈 수 있어야 함
- resend 버튼은 즉시 연속 탭되지 않아야 함

### 2. signup `429`

- `Retry-After`가 있으면 그 초 단위가 우선 반영되어야 함
- 없으면 `60s` fallback 사용
- 버튼 disabled + 남은 시간 노출

### 3. password reset `429`

- `password_reset` key로만 막혀야 함
- signup / email change action까지 같이 막히면 안 됨
- 없으면 `75s` fallback 사용

### 4. email change `429`

- `email_change` key로만 막혀야 함
- signed-in surface라도 낙관적 성공 표시 금지
- 없으면 `90s` fallback 사용

### 5. 네트워크 실패

- 상태는 `failed`
- 사용자는 즉시 다시 시도 가능
- 이전 성공 배너를 낙관적으로 유지하지 않음

### 6. 중복 탭

- `sending` 중 추가 탭은 억제됨
- metric/log에 `duplicate_suppressed=true`

### 7. dismiss / reopen

- `sent / cooldown / rate_limited` snapshot 유지
- 같은 이메일과 같은 action key라면 상태가 재현됨

### 8. background 복귀

- 현재 시각 기준으로 상태 재해석
- `nextAllowedAt`이 지났으면 자동으로 `idle` 복귀

## DoD

- 동일 사용자가 연속 탭으로 메일 발송 한도를 빠르게 소모하기 어렵습니다.
- `429` 발생 시 사용자는 남은 대기 시간을 이해할 수 있습니다.
- signup / reset / email change가 action key 기준으로 서로 잘못 막지 않습니다.
- 사용자에게 운영자용 내부 용어가 노출되지 않습니다.
- canonical code path, metric, QA 시나리오가 문서로 연결되어 있습니다.

## 관련 문서

- `docs/auth-mail-resend-state-machine-v1.md`
- `docs/auth-mail-observability-metric-alert-request-key-v1.md`
- `docs/auth-abuse-guard-policy-v1.md`
