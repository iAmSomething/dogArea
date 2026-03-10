# Epic #420 Closure Evidence v1

## 대상
- epic: `#420`
- title: `[Epic][Backend] Supabase Edge Function/RPC 플랫폼 안정화 1차`

## 하위 이슈 상태
- `#419` `[Backend/Auth] Edge Function 공통 인증/401·403 처리 계층 통합` -> `CLOSED`
- `#417` `[Backend/Contract] RPC·Edge 계약 버저닝과 호환성 정책 수립` -> `CLOSED`
- `#416` `[Backend/QA] Supabase integration test harness + smoke matrix 구축` -> `CLOSED`
- `#418` `[Backend/Ops] Edge Function 관측성·에러코드·런북 표준화` -> `CLOSED`

## 목적
- `#420`의 남은 DoD를 저장소 기준으로 다시 점검하고, 공통 인증/계약/검증/관측이 backend 플랫폼 계층으로 수렴했는지 확인한다.

## 실행 기준
- 기준 브랜치: `main`에서 분기한 `codex/epic-420-closure-evidence`
- 실행 명령:
  - `bash scripts/backend_pr_check.sh`
  - `DOGAREA_SKIP_BUILD=1 DOGAREA_SKIP_WATCH_BUILD=1 bash scripts/ios_pr_check.sh`
  - `swift scripts/epic_420_closure_evidence_unit_check.swift`
- 연계 문서:
  - `docs/backend-edge-auth-policy-v1.md`
  - `docs/backend-contract-versioning-policy-v1.md`
  - `docs/supabase-integration-smoke-matrix-v1.md`
  - `docs/backend-edge-observability-standard-v1.md`
  - `docs/backend-edge-error-taxonomy-v1.md`
  - `docs/backend-edge-incident-runbook-v1.md`

## DoD 판정

| DoD | 상태 | 근거 | 메모 |
| --- | --- | --- | --- |
| 주요 Edge Function에서 auth/error/envelope/logging 정책이 공통 기준으로 수렴한다 | `PASS` | `docs/backend-edge-auth-policy-v1.md`, `docs/backend-edge-auth-mode-inventory-v1.md`, `scripts/backend_edge_auth_unification_unit_check.swift`, `scripts/backend_edge_auth_inventory_unit_check.swift` | `verify_jwt=false + app/member bearer 공통 처리`, auth surface inventory, 공통 auth helper 기준이 저장소에 고정돼 있다. |
| 고위험 경로(`sync-walk`, `nearby-presence`, `rival-league`, `quest-engine`, `feature-control`)에 대해 실요청 smoke/integration 검증이 존재한다 | `PASS` | `docs/supabase-integration-smoke-matrix-v1.md`, `scripts/lib/supabase_integration_harness.sh`, `scripts/run_supabase_smoke_matrix.sh`, `scripts/backend_migration_drift_rpc_contract_unit_check.swift`, `bash scripts/backend_pr_check.sh` | smoke matrix와 backend check entrypoint가 저장소에 편입돼 있고, 고위험 route/RPC가 문서와 게이트에 모두 반영돼 있다. |
| RPC/Edge breaking change가 무계획 hotfix가 아니라 버전/호환성 정책 아래 관리된다 | `PASS` | `docs/backend-contract-versioning-policy-v1.md`, `docs/backend-high-risk-contract-matrix-v1.md`, `docs/backend-legacy-fallback-compat-sunset-plan-v1.md`, `scripts/backend_contract_versioning_unit_check.swift` | canonical envelope, `request_id`, fallback 수명, high-risk contract matrix가 문서와 정적 체크로 고정돼 있다. |
| backend 장애 시 `request_id` / `function_name` / `error_code` 기준으로 원인 역추적이 가능하다 | `PASS` | `docs/backend-edge-observability-standard-v1.md`, `docs/backend-edge-error-taxonomy-v1.md`, `docs/backend-edge-incident-runbook-v1.md`, `docs/backend-edge-failure-dashboard-view-v1.md`, `scripts/backend_edge_observability_unit_check.swift` | 공통 로그 메타, taxonomy, incident runbook, failure dashboard view 기준이 모두 저장소에 존재한다. |

## 핵심 증적

### 1. 인증/권한 공통화
- 공통 정책 문서: `docs/backend-edge-auth-policy-v1.md`
- 현재 함수별 인증 표면 inventory: `docs/backend-edge-auth-mode-inventory-v1.md`
- 게이트:
  - `swift scripts/backend_edge_auth_unification_unit_check.swift`
  - `swift scripts/backend_edge_auth_inventory_unit_check.swift`

### 2. 계약/호환성 관리
- 공통 버저닝 정책: `docs/backend-contract-versioning-policy-v1.md`
- 고위험 경로 매트릭스: `docs/backend-high-risk-contract-matrix-v1.md`
- fallback sunset 정책: `docs/backend-legacy-fallback-compat-sunset-plan-v1.md`
- 게이트:
  - `swift scripts/backend_contract_versioning_unit_check.swift`
  - `swift scripts/backend_migration_drift_rpc_contract_unit_check.swift`

### 3. 실요청 smoke/integration
- smoke matrix 문서: `docs/supabase-integration-smoke-matrix-v1.md`
- harness: `scripts/lib/supabase_integration_harness.sh`
- runner: `scripts/run_supabase_smoke_matrix.sh`
- backend entrypoint: `scripts/backend_pr_check.sh`
- 현재 저장소 기준 live smoke 실행 경로:
  - `DOGAREA_RUN_SUPABASE_SMOKE=1 DOGAREA_TEST_EMAIL=... DOGAREA_TEST_PASSWORD=... bash scripts/backend_pr_check.sh`

### 4. 관측성/오류 추적
- observability 표준: `docs/backend-edge-observability-standard-v1.md`
- error taxonomy: `docs/backend-edge-error-taxonomy-v1.md`
- incident runbook: `docs/backend-edge-incident-runbook-v1.md`
- failure dashboard view: `docs/backend-edge-failure-dashboard-view-v1.md`
- 게이트:
  - `swift scripts/backend_edge_observability_unit_check.swift`
  - `swift scripts/backend_edge_failure_dashboard_unit_check.swift`

## 결론
- `#420`의 하위 이슈는 모두 닫혀 있고, 인증/계약/실요청 smoke/관측성 4축이 저장소 문서와 게이트로 고정돼 있다.
- 즉, `#420`은 backend 플랫폼 안정화 1차 에픽으로 종료 가능하다.
