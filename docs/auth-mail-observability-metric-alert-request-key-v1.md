# Auth Mail Observability Metric / Alert / Request Key v1

Date: 2026-03-07  
Issue: #510

## 목적

Auth 메일 문제를 "429가 떴다", "메일이 안 왔다" 수준에서 끝내지 않고,
앱 진입점, 서버 판정, provider 결과를 같은 키로 연결해 운영자가 빨리 원인을 좁힐 수 있게 합니다.

이 문서는 아래를 함께 고정합니다.

- 최소 수집 metric
- request correlation key
- provider event 연결 기준
- dashboard 최소 패널
- alert 초안
- 사용자 문의 대응 시 확인할 runbook 필드

## 범위

대상 액션:

- signup confirmation
- password reset
- email change

대상 표면:

- iOS app auth entry
- Supabase Auth / custom SMTP path
- SMTP provider event/log

## Canonical 차원

모든 auth mail 관측성은 아래 차원을 기준으로 읽습니다.

- `action_type`
  - `signup_confirmation`
  - `password_reset`
  - `email_change`
- `surface`
  - 예: `signup_sheet`, `password_reset_sheet`, `settings_email_change`
- `request_id`
  - 한 번의 메일 액션 시도를 묶는 canonical correlation key
- `mail_action_key`
  - `action_type::recipient_hash::surface`
- `recipient_hash`
  - 정규화 이메일 자체가 아니라 hash 또는 mask된 식별값
- `result`
  - `attempted`, `accepted`, `rate_limited`, `failed`, `suppressed`, `bounce`, `reject`, `deferred`
- `retry_after_seconds`
  - `429` 또는 provider defer 시 대기 시간
- `duplicate_suppressed`
  - 중복 탭/중복 재시도가 억제되었는지
- `provider_name`
  - `resend`, `postmark`, `ses`
- `provider_message_id`
  - provider가 accepted 시 발급한 식별자
- `provider_event_id`
  - bounce/reject/deferred webhook 이벤트 식별자

## 최소 수집 대상

이 이슈에서 고정하는 최소 수집 항목은 아래입니다.

### 앱/클라이언트 metric

- signup mail send attempted
- signup mail sent
- reset mail send attempted
- reset mail sent
- email change mail send attempted
- email change mail sent
- `429 rate limited`
- `retry_after_seconds`
- `duplicate tap suppressed`

### provider / delivery event

- `bounce`
- `reject`
- `deferred`

## Canonical metric event 이름

DogArea app / backend / provider bridge는 아래 canonical event를 기준으로 정렬합니다.

- `auth_mail_send_attempted`
- `auth_mail_send_accepted`
- `auth_mail_action_rate_limited`
- `auth_mail_action_failed`
- `auth_mail_action_suppressed`
- `auth_mail_provider_bounce`
- `auth_mail_provider_reject`
- `auth_mail_provider_deferred`

### action_type 분리 원칙

이벤트 이름을 액션별로 늘리지 않고,
아래 payload 차원으로 분리합니다.

- `action_type=signup_confirmation`
- `action_type=password_reset`
- `action_type=email_change`

즉:

- signup mail send attempted
- reset mail send attempted
- email change mail send attempted

은 모두 `auth_mail_send_attempted` + `action_type`로 집계합니다.

## AppMetricTracker 기준

iOS 표면에서 다루는 최소 이벤트는 아래 raw value를 기준으로 합니다.

- `auth_mail_send_attempted`
- `auth_mail_send_accepted`
- `auth_mail_action_rate_limited`
- `auth_mail_action_failed`
- `auth_mail_action_suppressed`
- `auth_mail_provider_bounce`
- `auth_mail_provider_reject`
- `auth_mail_provider_deferred`

기존 resend UX metric은 유지하되,
운영 대시보드/alert는 위 canonical event를 우선 기준으로 삼습니다.

## Request Key / Correlation 기준

### 1. `request_id`

가장 중요한 상관관계 키입니다.

규칙:

- 사용자가 메일 액션 버튼을 한 번 누를 때마다 1개 생성
- 앱 로그 / 서버 로그 / provider metadata를 모두 이 키로 묶음
- retry 시 같은 요청의 연속 재시도면 같은 `request_id` 재사용 가능

### 2. `mail_action_key`

메일 액션 문맥 키입니다.

구성:

- `action_type`
- `recipient_hash`
- `surface`

예:

- `signup_confirmation::7df1...::signup_sheet`
- `password_reset::2b91...::password_reset_sheet`

용도:

- 동일 수신자/동일 표면/동일 액션의 패턴을 묶어 보기 위함
- 개인정보 raw email 대신 hash 사용

### 3. `provider_message_id`

provider가 accepted 응답에서 돌려주는 message 식별자입니다.

용도:

- "앱에서는 성공인데 실제 발송은 어땠는가"를 provider 이벤트와 연결

### 4. `provider_event_id`

provider webhook event 식별자입니다.

용도:

- bounce/reject/deferred 중복 집계 방지
- 장애 후속 분석 시 원본 이벤트 복구

## App / Server / Provider 연결 규칙

연결 순서는 아래입니다.

1. 앱 metric
   - `request_id`
   - `mail_action_key`
   - `action_type`
   - `surface`
2. 서버 로그 / auth gateway adapter
   - 같은 `request_id`
   - provider 호출 시 metadata/custom args에 전달
3. provider event/log
   - `request_id`
   - `mail_action_key`
   - `provider_message_id`
   - `provider_event_id`

즉, 운영자는 아래 순서로 추적합니다.

- 사용자 문의 시간/액션
- `request_id`
- `mail_action_key`
- provider accepted 여부
- bounce/reject/deferred 여부

## Provider metadata 표준

provider 전송 payload 또는 custom args에 아래 키를 실어야 합니다.

- `request_id`
- `mail_action_key`
- `action_type`
- `surface`
- `recipient_hash`

금지:

- raw email을 추가 메타로 중복 기록
- device id 같은 과한 식별자 추가

## Dashboard 최소 패널

### 1. 시간당 발송 수

축:

- x: 시간 버킷
- series: `action_type`
- metric: `auth_mail_send_attempted`

### 2. action별 성공률

정의:

- `accepted / attempted`

필터:

- `action_type`

### 3. 429 비율

정의:

- `rate_limited / attempted`

축:

- 전체
- `action_type`
- `surface`

### 4. bounce / reject / deferred 비율

정의:

- `provider_bounce / accepted`
- `provider_reject / accepted`
- `provider_deferred / accepted`

### 5. retry_after_seconds 분포

용도:

- 특정 시간대 abuse 또는 provider throttling 징후 확인

### 6. duplicate suppressed 비율

정의:

- `suppressed / attempted`

용도:

- UI 중복 탭 억제가 과도한지, 실제 사용자가 버튼을 헷갈리는지 확인

## Alert 초안

초안은 운영 초기값입니다.
실데이터가 쌓이면 2주 단위로 조정합니다.

### Warning

- signup confirmation success rate `< 97%` for `15m`
- password reset success rate `< 97%` for `15m`
- email change success rate `< 95%` for `15m`
- `429 ratio > 5%` for `15m`
- `bounce ratio > 2%` for `30m`
- `deferred ratio > 10%` for `30m`

### Critical

- signup confirmation success rate `< 90%` for `15m`
- password reset success rate `< 90%` for `15m`
- `429 ratio > 15%` for `15m`
- `reject ratio > 3%` for `30m`
- accepted event는 있는데 provider event가 비정상적으로 0 또는 누락되는 상태가 `30m` 지속

## 사용자 문의 대응 필드

운영자가 사용자 문의를 받을 때 최소 아래 필드를 확인해야 합니다.

- 문의 시각
- action type
- 앱 build / version
- surface
- masked recipient 또는 `recipient_hash`
- `request_id`
- `mail_action_key`
- UI 상태
  - attempted / accepted / rate_limited / failed / suppressed
- `retry_after_seconds`
- `duplicate_suppressed`
- `provider_name`
- `provider_message_id`
- `provider_event_id`
- provider 최종 상태
  - accepted / bounce / reject / deferred
- provider reason / SMTP response

## 운영 해석 규칙

### 1. attempted는 있는데 accepted가 낮다

가능성:

- 앱에서 서버 전 단계 실패
- auth API 실패
- custom SMTP auth failure

### 2. accepted는 높은데 문의가 늘어난다

가능성:

- provider accepted 후 delivery 문제
- spam/junk 분류
- bounce / deferred 증가

### 3. 429 ratio가 높다

가능성:

- abuse 증가
- cooldown UX 부족
- 특정 surface에서 중복 탭이 많음

### 4. duplicate suppressed가 급증한다

가능성:

- 버튼 위계/상태 문구가 불명확
- 사용자가 resend 가능 시점을 예측하기 어려움

## Runbook 연결

auth mail 문의/incident 시 아래 문서와 함께 봅니다.

- `docs/auth-mail-resend-state-machine-v1.md`
- `docs/auth-captcha-insertion-fallback-ux-v1.md`
- `docs/auth-smtp-provider-selection-dns-secret-checklist-v1.md`
- `docs/backend-request-correlation-idempotency-policy-v1.md`
- `docs/backend-edge-incident-runbook-v1.md`

## 단계별 적용

### Phase 1

- event 이름 고정
- request key 기준 고정
- dashboard/alert/runbook 문서화

### Phase 2

- provider metadata에 `request_id`, `mail_action_key` 실제 삽입
- provider webhook ingest와 dashboard 연결

### Phase 3

- alert 자동화
- support inquiry lookup 도구화
