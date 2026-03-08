# Auth Abuse Guard Policy v1

Date: 2026-03-08  
Issue: #484

## 목적

DogArea의 이메일 인증 경로에서 메일 발송 한도 소모와 abuse를 줄이기 위해,
아래를 action별로 함께 고정합니다.

- CAPTCHA 적용 여부와 삽입 위치
- endpoint별 rate limit 운영값
- resend 최소 간격
- 이상 징후 metric / dashboard / alert
- 자동 완화 / 수동 대응 기준
- 앱 UX, 운영 문서, Supabase 설정의 정합성 기준

## 범위

포함:

- signup / password reset / email change / invite mail의 abuse guard 정책
- CAPTCHA step-up 도입 판단
- IP / email / global 발송량 기준 초안
- 운영 metric / alert / runbook 연결

제외:

- custom SMTP provider 실제 전환
- CAPTCHA provider 실제 도입
- 버그 리포트 / 일반 서비스 메일 기능 구현

## 전제

- DogArea는 public email auth surface를 운영하므로, `rate limit만 올려서 해결`하는 접근을 금지합니다.
- CAPTCHA는 정상 사용자의 기본 단계가 아니라 **step-up friction** 입니다.
- action별 위험도와 정상 사용자 기대가 다르므로, signup / recovery / email change를 하나의 단일 정책으로 뭉개지 않습니다.
- `invite`는 현재 활성화되지 않았더라도, 향후 사용 시 auth mail과 같은 경로를 재활용하지 않도록 미리 기준을 둡니다.

## 관련 문서와 역할 분리

- `docs/auth-captcha-insertion-fallback-ux-v1.md`
  - iOS에서 CAPTCHA를 어떤 표면으로 삽입할지 정의
- `docs/auth-mail-observability-metric-alert-request-key-v1.md`
  - auth mail metric / alert / correlation key 정의
- `docs/auth-service-mail-channel-separation-policy-v1.md`
  - auth mail과 service mail 채널 분리 정책 정의
- 이 문서
  - action별 abuse guard 운영값과 자동 완화 기준을 묶는 상위 정책

## 액션별 위협 모델 요약

| 액션 | 표면 | 주요 위험 | 정상 사용자 보호 포인트 |
| --- | --- | --- | --- |
| 회원가입 | public onboarding | bot signup, 메일 폭탄, sender reputation 소모 | friction 최소화, 첫 전환율 보호 |
| 비밀번호 재설정 | public recovery | 계정 enumeration, reset flood, 메일 폭탄 | 실제 계정 소유자 복구 UX 보호 |
| 이메일 변경 | signed-in settings | 세션 탈취 후 메일 남발, 대상 이메일 spam | 재인증 이후에도 과도한 friction 금지 |
| 초대 메일 | 향후 service surface | 대량 초대 abuse, referral spam | auth mail과 완전 분리 |

## CAPTCHA 정책

### 결론

- `signup`: **step-up CAPTCHA 채택**
- `password reset`: **step-up CAPTCHA 채택**, signup보다 더 보수적 threshold 허용
- `email change`: **조건부 step-up CAPTCHA 채택**, 재인증 이후에도 이상 징후일 때만 적용
- `invite`: auth 경로가 아니라 `Service Mail API` 경로에서 별도 abuse guard 적용

### always-on CAPTCHA 판단

DogArea는 아래 이유로 always-on CAPTCHA를 채택하지 않습니다.

1. 정상 사용자 가입/복구 전환율 손실이 큽니다.
2. signed-in email change까지 같은 마찰을 주는 건 과도합니다.
3. 이미 `Retry-After`, resend cooldown, duplicate suppression, metric 수집 축이 있으므로 step-up 조합이 더 합리적입니다.

### step-up 기준

아래 중 하나라도 만족하면 CAPTCHA step-up을 허용합니다.

- 같은 IP에서 짧은 시간 안에 다수 이메일 대상으로 반복 요청
- 같은 이메일에 짧은 시간 안에 반복 요청
- endpoint별 `429 ratio`가 기준치를 넘는 구간이 지속
- provider bounce / reject / deferred 비율이 급증
- 운영자가 incident 대응 중 임시 강화를 적용

### iOS 배치 기준

앱 배치 방식은 `docs/auth-captcha-insertion-fallback-ux-v1.md`를 따릅니다.

- 기본은 서버 판정 기반 step-up
- native explainer sheet + `ASWebAuthenticationSession`
- 실패/취소/네트워크 오류 시 입력값 유지 후 원래 폼으로 복귀

## 운영 rate limit 초기값

아래 값은 **production canonical initial value** 입니다.

주의:

- repo의 `supabase/config.toml`은 local dev / smoke용 값이므로 이 표와 동일할 필요가 없습니다.
- hosted Supabase Auth / provider 운영값은 아래 표를 기준으로 관리합니다.
- 상향은 관측성 근거 없이 하지 않습니다.

| 액션 | resend 최소 간격 | IP 기준 초기값 | email 기준 초기값 | global 발송량 초기값 | 기본 CAPTCHA 정책 |
| --- | --- | --- | --- | --- | --- |
| 회원가입 확인 메일 | `60s` | `10 requests / 5m / IP` | `3 sends / 30m / email` | `120 sends / h / project` | step-up |
| 비밀번호 재설정 메일 | `90s` | `8 requests / 5m / IP` | `3 sends / 30m / email` | `90 sends / h / project` | step-up, signup보다 보수적 |
| 이메일 변경 확인 메일 | `120s` | `6 requests / 5m / IP` | `2 sends / 30m / email` | `60 sends / h / project` | signed-in step-up only |
| 초대 메일 | auth 경로 사용 금지 | service mail policy로 별도 관리 | service mail policy로 별도 관리 | service mail policy로 별도 관리 | auth CAPTCHA 대상 아님 |

## 상향 / 하향 기준

### 값 상향이 허용되는 조건

아래를 모두 만족할 때만 초기값 상향을 검토합니다.

1. `429 ratio`는 높지만 bot/abuse 패턴 증거는 약함
2. bounce / reject / deferred 비율이 안정적임
3. support 문의나 전환 지표에서 정상 사용자 불편이 반복적으로 확인됨
4. 상향 전후 metric 비교 기간과 rollback 조건이 문서화됨

### 값 하향 또는 즉시 강화 조건

아래 중 하나라도 만족하면 CAPTCHA 강제 또는 더 보수적 rate limit을 적용합니다.

- 같은 IP에서 다수 이메일 대상으로 요청이 급증
- 같은 이메일에 대한 짧은 시간 내 반복 요청 급증
- `429 ratio > 5% for 15m`이 signup/reset에서 지속
- provider `bounce/reject/deferred` 비율이 급증
- support에서 abuse / 스팸 패턴을 확인

## 자동 완화 / 수동 대응 기준

| 징후 | 자동 완화 | 수동 대응 |
| --- | --- | --- |
| signup `429 ratio > 5% for 15m` | signup step-up CAPTCHA 강제 | dashboard / provider log 확인 |
| password reset 같은 IP 다중 이메일 요청 급증 | reset threshold를 signup보다 먼저 강화 | enumeration / scripted abuse 검토 |
| email change가 정상 세션에서 반복 실패 | resend cooldown 유지, 즉시 전역 강화는 금지 | support/manual review로 전환 |
| provider bounce / reject 급증 | 발송량 상향 금지, CAPTCHA 강화 검토 | sender reputation / provider incident 확인 |
| 동일 사용자 반복 차단 문의 | 자동 강화 유지 | support가 manual review 후 예외 처리 여부 판단 |

manual review로 넘기는 조건:

- 정상 사용자로 보이나 `429`와 CAPTCHA가 반복되어 진행이 불가능한 경우
- signed-in email change에서 재인증 이후에도 반복 차단되는 경우
- 특정 네트워크 환경에서 과도한 false positive가 확인되는 경우

## 정상 사용자 보호 원칙

- signup은 friction보다 전환율 손실이 더 크므로 always-on CAPTCHA 금지
- password reset은 abuse 방어 우선이지만, 안내 문구는 복구 행동 중심으로 유지
- email change는 signed-in trusted surface이므로 가장 낮은 friction 유지
- `Retry-After`와 resend cooldown은 action별 key로 분리하여 서로 잘못 막지 않게 유지
- 서버 성공 전에는 절대 `전송 완료` 상태를 낙관적으로 표시하지 않음

## 관측성 기준

canonical metric / key는 `docs/auth-mail-observability-metric-alert-request-key-v1.md`를 따릅니다.

필수 dashboard 축:

- 시간당 auth mail 발송 수
- endpoint별 `429 ratio`
- 같은 IP가 다수 이메일 대상으로 요청한 횟수
- 같은 이메일에 대한 짧은 시간 내 반복 요청
- provider `bounce / reject / deferred`
- `retry_after_seconds` 분포

추가로 이 문서에서 운영자가 같이 봐야 할 축:

- `captcha step-up presented / completed / cancelled / failed`
- action별 false-positive support ticket 수
- action별 resend suppressed count

## 앱 / 설정 / 운영 정합성 규칙

### 앱 UX

- `EmailSignUpSheetView`는 signup resend cooldown / Retry-After / duplicate suppression의 canonical UI surface입니다.
- reset / email change UI를 추가할 때도 action key 분리와 `Retry-After` 우선순위를 그대로 재사용합니다.
- 사용자에게 `SMTP`, `Rate Limit`, `over_email_send_rate_limit` 같은 운영자 용어를 노출하지 않습니다.

### Supabase / provider 설정

- local `supabase/config.toml` 값은 local CLI 테스트용이며 production canonical 값이 아닙니다.
- hosted Supabase Auth / SMTP / provider 운영값은 이 문서 표를 기준으로 관리합니다.
- hosted 운영값을 바꿀 때는 observability 문서, CAPTCHA 문서, 앱 UX와 충돌하지 않아야 합니다.

### 서비스 메일 경로

- 초대 메일과 향후 일반 메일은 auth SMTP를 공유하지 않습니다.
- `docs/auth-service-mail-channel-separation-policy-v1.md`의 service mail 경로를 따릅니다.

## QA 시나리오

1. signup 연속 탭
- 동일 액션에 대해 중복 탭이 억제되어야 함
- `duplicate_suppressed=true`가 metric에 남아야 함

2. signup `429 + Retry-After`
- 남은 시간이 사용자 문구로 표시되어야 함
- resend 버튼은 남은 시간 동안 disabled

3. password reset abuse signal
- step-up CAPTCHA가 signup보다 더 보수적으로 발동 가능해야 함
- 성공/취소/실패 복귀 UX는 CAPTCHA 문서와 일치해야 함

4. email change false positive
- 전역 차단이 아니라 해당 action surface 중심으로 복구 가능해야 함
- 필요 시 support/manual review 경로를 안내해야 함

5. provider bounce / reject 급증
- 발송량 상향 없이 incident runbook과 dashboard로 대응해야 함

## DoD

- signup / password reset / email change / invite의 abuse guard 정책이 action별로 분리되어 있습니다.
- CAPTCHA 적용 여부와 위치가 문서로 명확합니다.
- IP / email / global / resend 기준 초기값과 상향 조건이 문서화되어 있습니다.
- metric / dashboard / alert / manual review 기준이 연결되어 있습니다.
- 앱 UX, 운영 문서, Supabase 설정의 관계가 서로 모순되지 않게 정리되어 있습니다.

## 관련 문서

- `docs/auth-captcha-insertion-fallback-ux-v1.md`
- `docs/auth-mail-observability-metric-alert-request-key-v1.md`
- `docs/auth-service-mail-channel-separation-policy-v1.md`
- `docs/auth-smtp-provider-selection-dns-secret-checklist-v1.md`
