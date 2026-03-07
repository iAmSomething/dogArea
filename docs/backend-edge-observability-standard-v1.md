# Backend Edge Observability Standard v1

Date: 2026-03-07  
Issue: #418

## 목적

DogArea Supabase Edge Function이 장애, fallback, privacy suppression, auth mismatch를 겪을 때 운영자가 **같은 해석 체계**로 로그와 응답을 읽을 수 있게 최소 메타데이터와 로그 규칙을 고정합니다.

이 문서는 외부 SaaS 도입 문서가 아닙니다. 함수 내부 로그, 응답 메타, smoke/runbook이 같은 기준을 쓰도록 맞추는 운영 표준입니다.

## 대상 함수

우선순위 대상:

- `feature-control`
- `sync-walk`
- `sync-profile`
- `nearby-presence`
- `rival-league`
- `quest-engine`
- `upload-profile-image`
- `caricature`

## 공통 로그 메타 필드

모든 고위험 Edge Function은 start / success / failure 로그 또는 동등한 audit 흔적에서 아래 필드를 식별 가능하게 남겨야 합니다.

- `function_name`: canonical Edge Function 이름
- `request_id`: 요청 상관관계 ID
- `version`: 협상된 계약 버전 또는 서버 canonical 버전
- `latency_ms`: 요청 시작부터 응답까지의 처리 시간
- `auth_mode`: `anon|authenticated|service_role_proxy|mixed`
- `fallback_used`: compat route / legacy signature / provider fallback 사용 여부
- `rpc_name`: 주요 DB RPC 호출명이 있으면 기록
- `error_code`: taxonomy 기준 machine-readable 코드
- `cooldown_key`: 404 cooldown / rollout cooldown / retry suppression이 있으면 키 기록
- `policy_key`: privacy / abuse / moderation 정책 이름이 있으면 기록

## 로그 이벤트 규약

### 1. request_received

최소 필드:

- `function_name`
- `request_id`
- `version`
- `auth_mode`
- `action`

### 2. request_succeeded

최소 필드:

- `function_name`
- `request_id`
- `version`
- `latency_ms`
- `fallback_used`
- `rpc_name` 또는 `rpc_names`

### 3. request_failed

최소 필드:

- `function_name`
- `request_id`
- `version`
- `latency_ms`
- `error_code`
- `message`
- `fallback_used`
- `rpc_name`

## 응답 메타 표준

계약 버전 규칙은 `docs/backend-contract-versioning-policy-v1.md`를 따릅니다.

### Success

고위험 함수 성공 응답은 아래 메타를 목표로 합니다.

```json
{
  "ok": true,
  "version": "2026-03-07.v1",
  "request_id": "req_123",
  "latency_ms": 42,
  "fallback_used": false
}
```

도메인 payload는 기존 top-level 키를 유지합니다.

### Error

고위험 함수 오류 응답은 아래 메타를 목표로 합니다.

```json
{
  "ok": false,
  "error": "UNAUTHORIZED",
  "code": "UNAUTHORIZED",
  "message": "authorization header required",
  "request_id": "req_123",
  "version": "2026-03-07.v1",
  "latency_ms": 7,
  "fallback_used": false
}
```

규칙:

- `error`는 v1 호환 alias로 유지 가능
- `code`는 taxonomy canonical 값
- `message`는 운영자가 원인을 판단할 수 있는 수준으로 남김
- 기존 앱 파서가 깨지지 않도록 도메인 키는 제거하지 않음

## auth_mode 규칙

- `anon`: anon bearer 또는 public execution
- `authenticated`: member bearer 검증 완료
- `service_role_proxy`: 함수 내부에서 service role로 DB 호출하지만 요청은 인증됨
- `mixed`: anon/app policy와 member policy가 섞인 경우

예시:

- `feature-control`: `anon`
- `rival-league`: `authenticated`
- `nearby-presence`: `mixed`
- `caricature`: `authenticated`

## fallback_used 규칙

`fallback_used=true`로 기록해야 하는 경우:

- legacy route fallback 사용 (`sync_walk` 등)
- legacy RPC signature delegate 사용
- provider fallback 사용 (`Gemini -> OpenAI` 등)
- anon retry / alternate auth path 사용

`fallback_used=false`로 기록해야 하는 경우:

- canonical route / canonical RPC / primary provider만 사용

## privacy / abuse 메타 규칙

아래 도메인은 응답 또는 audit log에서 suppression 정보를 반드시 식별 가능하게 남깁니다.

### nearby-presence

- `suppression_reason`
- `delay_minutes`
- `required_min_sample`
- `abuse_reason`
- `abuse_score`
- `sanction_level`

### rival / quest / season 권리경로

- privacy 또는 abuse에 의해 차단되면 `policy_key`와 `error_code`를 함께 남김

## rollout / cooldown 메타 규칙

다음 유형의 보호 장치가 있으면 로그에 표시해야 합니다.

- 404 function cooldown
- feature flag rollout block
- auth retry suppression
- privacy guard suppression

최소 필드:

- `cooldown_key`
- `cooldown_ttl_sec` 또는 `retry_after_sec`
- `fallback_used`

## adoption 우선순위

### 1차: 지금 바로 문서/정적 체크에 반영

- 함수별 현재 메타 보유 상태 표준 문서화
- 에러 taxonomy 명문화
- runbook 명문화
- smoke / static check 연결

### 2차: 후속 refactor issue에서 runtime 통일

- 공통 error/helper 모듈 추출
- request_id/version 자동 주입
- success/error envelope helper 통일
- structured log helper 도입

## Validation

- `swift scripts/backend_edge_observability_unit_check.swift`
- `bash scripts/backend_pr_check.sh`
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`

## Related

- `docs/backend-edge-error-taxonomy-v1.md`
- `docs/backend-edge-incident-runbook-v1.md`
- `docs/backend-edge-observability-adoption-matrix-v1.md`
- `docs/backend-contract-versioning-policy-v1.md`
- `docs/game-layer-observability-qa-v1.md`
- `docs/feature-flag-rollout-monitoring-v1.md`
