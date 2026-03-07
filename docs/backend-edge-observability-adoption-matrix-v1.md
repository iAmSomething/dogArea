# Backend Edge Observability Adoption Matrix v1

Date: 2026-03-07  
Issue: #418

## Matrix

| Function | Current observability signal in source | Current error shape | Special metadata | Gap to standard | Follow-up |
| --- | --- | --- | --- | --- | --- |
| `caricature` | `request_id`, `errorCode`, `fallback_used`, `latency_ms` persisted/loggable | `errorCode` + `message` 중심 | provider fallback, storage/provider failure, schema version | 가장 표준에 가까움. success/error envelope helper만 공통화 필요 | `#438` |
| `nearby-presence` | `console.error`, privacy audit insert, hotspot compat signature logging | legacy `error` + 일부 `code` | `suppression_reason`, `delay_minutes`, `required_min_sample`, `abuse_reason`, `abuse_score`, `sanction_level` | `request_id`, `version`, `latency_ms`, `auth_mode` 메타 추가 필요 | `#425`, `#431`, `#438` |
| `sync-walk` | 404 fallback 정책은 문서/클라이언트에 존재 | legacy `error` only | route fallback / cooldown은 클라이언트에서 추적 | function-side `request_id`, `version`, `latency_ms`, `fallback_used`, structured error code 필요 | `#424`, `#437`, `#438` |
| `sync-profile` | auth/user mismatch path 구분 | legacy `error` only | user mismatch `403` | request_id/version/latency/error taxonomy 메타 추가 필요 | `#419`, `#438` |
| `rival-league` | jsonb RPC wrapper path 사용 | legacy `error` only | leaderboard compat RPC delegate | request_id/version/latency/error taxonomy/fallback_used 추가 필요 | `#419`, `#437`, `#438` |
| `quest-engine` | `requestId`를 claim RPC에 일부 전달 | legacy `error` only | reward claim idempotency trace 일부 존재 | canonical `request_id`, version, latency, auth_mode, standardized code 필요 | `#419`, `#438` |
| `feature-control` | rollout KPI/ops 문서 존재 | legacy `error` only | rollout / flags / KPI endpoints | function_name/request_id/version/error taxonomy/log metadata 추가 필요 | `#438` |
| `upload-profile-image` | storage failure branch 명확 | legacy `error` + `detail` | upload/public URL failure | request_id/version/latency/auth_mode/error taxonomy 추가 필요 | `#433`, `#438` |

## Adoption Rule

- Wave 1: 문서 + static check + smoke 연결
- Wave 2: shared helper 도입으로 success/error envelope 표준화
- Wave 3: request_id/version/auth_mode/fallback_used 자동 주입

## 최소 합격선

운영상 "관측 가능"으로 판단하려면 아래 3개가 모두 가능해야 합니다.

1. 함수 이름을 식별할 수 있다
2. 에러 category 또는 canonical code로 분류할 수 있다
3. fallback/privacy/abuse 여부를 로그나 응답에서 식별할 수 있다

## Validation

- `swift scripts/backend_edge_observability_unit_check.swift`
