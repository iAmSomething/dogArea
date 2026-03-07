# Backend Edge Incident Runbook v1

Date: 2026-03-07  
Issue: #418

## 목적

Edge Function 장애가 발생했을 때 함수별 감이 아니라 공통 절차로 역추적할 수 있도록 triage 순서를 고정합니다.

## 1. 최초 분류

장애를 보면 먼저 아래를 채웁니다.

- `function_name`
- `request_id`
- `version`
- `auth_mode`
- `error_code`
- `fallback_used`
- `rpc_name`
- `latency_ms`

이 필드가 응답/로그/DB audit 중 어디에 남았는지 찾는 것이 첫 단계입니다.

## 2. 로그/응답에서 읽을 순서

1. `error_code` 또는 legacy `error`
2. `function_name`
3. `request_id`
4. `fallback_used`
5. `rpc_name`
6. privacy / abuse 메타 (`suppression_reason`, `abuse_reason`, `sanction_level`)
7. `latency_ms`

## 3. 분류별 대응

### auth

확인:

- bearer 헤더 존재 여부
- member token 유효성
- anon retry가 있었는지
- 함수 auth mode가 의도와 맞는지

관련 이슈/문서:

- `#419`
- `#431`

### contract

확인:

- `action`, `stage`, `payload`, `version` shape
- canonical route / legacy route fallback 여부
- RPC positional vs `payload jsonb` 경로

관련 문서:

- `docs/backend-contract-versioning-policy-v1.md`
- `docs/backend-high-risk-contract-matrix-v1.md`
- `docs/sync-walk-404-fallback-policy-v1.md`

### unavailable

확인:

- 함수가 실제 배포되었는지
- RPC/migration drift가 없는지
- 404 cooldown 또는 rollout block이 걸렸는지
- config/secret 누락인지

실행 커맨드:

```bash
bash scripts/backend_pr_check.sh
DOGAREA_RUN_SUPABASE_SMOKE=1 DOGAREA_TEST_EMAIL=... DOGAREA_TEST_PASSWORD=... bash scripts/backend_pr_check.sh
```

관련 문서/이슈:

- `#436`
- `#427`
- `#439`
- `docs/backend-deploy-rollback-roll-forward-runbook-v1.md`
- `docs/backend-edge-secret-inventory-rotation-runbook-v1.md`

### privacy

확인:

- `suppression_reason`
- `delay_minutes`
- `required_min_sample`
- visibility enabled 여부
- audit log insert 실패 여부

관련 문서:

- `docs/rival-privacy-hard-guard-v1.md`
- `docs/hotspot-widget-privacy-mapping-v1.md`

### upstream

확인:

- RPC 명과 SQL migration 존재 여부
- Storage 업로드 실패인지
- provider/router fallback 사용 여부

관련 이슈:

- `#433`
- `#438`

### abuse

확인:

- `abuse_reason`
- `abuse_score`
- `sanction_level`
- `sanction_until`

## 4. alert / dashboard 연결

운영자가 기본으로 보는 기준:

- backend failure dashboard: `docs/backend-edge-failure-dashboard-view-v1.md`
- game-layer KPI: `docs/game-layer-observability-qa-v1.md`
- rollout KPI: `docs/feature-flag-rollout-monitoring-v1.md`
- live smoke matrix: `docs/supabase-integration-smoke-matrix-v1.md`
- deploy verification / matrix: `#436`

## 5. 대표 시나리오

### A. 404 / function not deployed

- smoke matrix에서 route 404 확인
- cooldown 적용 여부 확인
- deploy matrix와 rollback/roll-forward runbook 확인

### B. anon retry / auth downgrade

- 요청이 `authenticated`였는지, fallback이 `anon`으로 내려갔는지 확인
- local session invalidate가 실제로 발생했는지 확인
- 함수가 `mixed` auth mode인지 확인

### C. nearby suppression / privacy guard

- `suppression_reason`와 `privacy_mode` 확인
- hotspot / live presence audit log 삽입 결과 확인
- `required_min_sample`, `delay_minutes`, `obfuscation_meters` 확인

### D. provider fallback

- `fallback_used=true`인지 확인
- primary provider와 fallback provider 중 어느 단계에서 실패했는지 확인
- `latency_ms`와 provider 실패 코드를 함께 확인

## 6. 운영 후속 조치 규칙

- incident가 contract 문제면 문서/compat matrix도 같이 갱신
- incident가 deploy 문제면 smoke matrix 케이스를 추가하거나 강화
- incident가 auth/privacy 문제면 taxonomy와 auth_mode 표준을 같이 수정

## Validation

- `swift scripts/backend_edge_observability_unit_check.swift`
- `bash scripts/backend_pr_check.sh`
