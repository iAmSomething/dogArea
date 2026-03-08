# Backend Legacy Fallback / Compat Sunset Plan v1

Date: 2026-03-07  
Issue: #437

## 목적

DogArea backend에는 장애 회피와 호환성 유지를 위한 fallback/compat 경로가 실제로 존재합니다.

문제는 fallback 자체가 아니라, 아래가 없을 때입니다.

- 어떤 경로가 임시 debt인지
- 어떤 경로가 장기 safety rail인지
- 언제 제거할 수 있는지
- 어떤 smoke/metric/log로 제거 판단을 할지

이 문서는 그 기준을 backend 운영 관점에서 고정합니다.

## 분류

### 1. `temporary_compat_debt`

구버전 앱, 이전 RPC signature, legacy env name을 잠시 받기 위한 경로입니다.

원칙:

- 기본적으로 sunset 대상입니다.
- `2개 앱 릴리즈 또는 14일`, 둘 중 더 긴 기간을 최소 유지합니다.
- `post-deploy smoke 2회 연속 통과` 전에는 제거하지 않습니다.

### 2. `long_lived_safety_rail`

배포 미스, provider 장애, route 누락 시 폭주나 기능 중단을 막기 위한 보호장치입니다.

원칙:

- compat debt가 아니라 운영 safety rail로 취급합니다.
- 제거보다 “대체 제어 수단이 생겼는가”를 먼저 봅니다.

### 3. `legacy_data_bridge`

예전 seed/데이터 category를 잠시 유지해 사용자 경험이나 비교 데이터를 끊지 않기 위한 bridge입니다.

원칙:

- authoritative 데이터가 충분히 대체할 때까지 유지할 수 있습니다.
- 장기 유지 시에도 활성/노출 범위와 정합성 검증이 필요합니다.

## Sunset Baseline Rule

모든 sunset 후보는 아래를 만족해야 합니다.

1. canonical 경로가 문서에 명시돼 있다  
2. smoke/static check가 canonical 경로를 커버한다  
3. 최근 2회 post-deploy에서 관련 smoke가 연속 통과했다  
4. legacy path hit이 0 또는 제거 가능한 수준임을 로그/metric/manual audit로 설명할 수 있다  
5. 제거 후 rollback 또는 delegate 재활성 절차가 문서화돼 있다

중요:

- **metric이 없으면 제거를 서두르지 않습니다.**
- metric gap이 있으면 최소한 smoke + source audit + 운영 로그 검토를 먼저 남겨야 합니다.

## Inventory

| Surface | Current fallback / compat path | Class | Keep reason | Sunset / keep decision | Evidence source |
| --- | --- | --- | --- | --- | --- |
| `sync-walk` Edge route | canonical `sync-walk` + legacy route fallback `sync_walk` | `temporary_compat_debt` | 실제 `404` 장애 이력이 있고, canonical 미배포 시 업로드 폭주를 막아야 했음 | canonical route만으로 `2회` post-deploy smoke 통과 + legacy route hit 없음 확인 후 제거 검토 | `docs/sync-walk-404-fallback-policy-v1.md`, `scripts/sync_walk_404_policy_unit_check.swift`, `sync-walk.session.member`, `sync-walk.summary.member` |
| `sync-walk` function unavailable cooldown | `404` 시 임시 unavailable marker로 재호출 차단 | `long_lived_safety_rail` | 미배포/오배포 환경에서 outbox 반복 호출을 차단 | 당장은 유지. 별도 deploy guarantee/retry governor가 대체하기 전 제거 금지 | `docs/sync-walk-404-fallback-policy-v1.md`, `scripts/sync_walk_404_policy_unit_check.swift` |
| `rpc_get_rival_leaderboard` 3-arg delegate | canonical `payload jsonb` + positional delegate | `temporary_compat_debt` | PostgREST / widget / older callers compat 유지 | canonical wrapper만으로 caller 전환 완료 + `rival-rpc.compat.member`/widget summary smoke 2회 통과 후 제거 검토 | `scripts/rival_rpc_param_compat_unit_check.swift`, `scripts/backend_migration_drift_rpc_contract_unit_check.swift`, `rival-rpc.compat.member`, `widget-quest-rival.summary.member` |
| `rpc_get_widget_quest_rival_summary(timestamptz)` delegate | canonical `payload jsonb` + compat delegate | `temporary_compat_debt` | 기존 timestamptz caller compat 유지 | payload wrapper만 남겨도 되는지 caller inventory 확인 후 제거 검토 | `scripts/rival_rpc_param_compat_unit_check.swift`, `widget-quest-rival.summary.member` |
| `rpc_get_nearby_hotspots` legacy signature | latest `in_center_*` + legacy `center_*` fallback | `temporary_compat_debt` | migration hotfix 이후 signature 편차 흡수 | latest signature smoke와 widget hotspot smoke 안정화 후 legacy signature 제거 검토 | `supabase/functions/nearby-presence/support/hotspot_compat.ts`, `scripts/backend_migration_drift_rpc_contract_unit_check.swift`, `nearby-presence.hotspots.app_policy`, `widget-hotspot.summary.member` |
| `quest-engine` request key alias | `requestId`, `eventId`, `instanceId`, `target_instance_id` 허용 | `temporary_compat_debt` | 기존 transport/event payload와의 호환 유지 | canonical `request_id`, `idempotency_key`, `event_id`, `instance_id`만 남겨도 앱/스크립트가 깨지지 않을 때 제거 | `docs/backend-request-correlation-idempotency-policy-v1.md`, `scripts/backend_request_id_idempotency_unit_check.swift` |
| `feature-control` 404 cooldown | function unavailable cooldown | `long_lived_safety_rail` | 미배포 상태에서 flag/KPI read 폭주를 막음 | rollout/deploy 가드가 더 강한 중앙 제어로 대체되기 전 유지 | `scripts/feature_control_404_cooldown_unit_check.swift`, `feature-control.flags.anon`, `feature-control.rollout_kpis.anon` |
| `caricature` provider fallback | `Gemini -> OpenAI` provider fallback | `long_lived_safety_rail` | provider outage/쿼터/정책 변동 시 기능 가용성 유지 | single-provider 운영 전략이 제품적으로 승인되기 전 유지 | `supabase/functions/caricature/README.md`, `scripts/caricature_proxy_unit_check.swift`, `docs/image-provider-router-v1.md` |
| `area_references.category = legacy` seed | authoritative source 미정/과거 비교군 유지용 legacy rows | `legacy_data_bridge` | 과거 비교군 가시성 유지, seed 정합성 유지 | authoritative catalog replacement와 `is_active` 정리 계획이 생기면 축소. 즉시 삭제 금지 | `docs/area-references-data-governance.md`, `scripts/area_reference_catalog_seed_unit_check.swift` |

## Sunset Evidence Ladder

### A. `temporary_compat_debt`

제거 전 체크:

- canonical smoke case 2회 연속 통과
- static contract check 통과
- legacy path caller inventory 0건 또는 migration된 근거 확보
- post-deploy note에 rollback 방법 명시

권장 evidence:

- smoke case PASS 로그
- source grep 또는 migration inventory
- 최근 운영 로그에서 fallback hit 없음

### B. `long_lived_safety_rail`

제거 전 체크:

- 같은 보호 효과를 주는 대체 제어 존재
- 대체 제어가 실제 장애 시나리오를 커버함
- 30일 incident-free 운영 데이터 또는 동등한 운영 근거

즉, cooldown/provider fallback은 "보기 싫다"는 이유로 제거하지 않습니다.

### C. `legacy_data_bridge`

제거 전 체크:

- authoritative replacement dataset 존재
- validation SQL 통과
- 기존 비교 카드/정렬/노출에 regression 없음
- active legacy rows를 비활성화해도 사용자 경험이 깨지지 않음

## Current Recommendation Order

가장 먼저 sunset 검토할 후보:

1. `rpc_get_nearby_hotspots` legacy signature
2. `rpc_get_widget_quest_rival_summary(timestamptz)` delegate
3. `rpc_get_rival_leaderboard` 3-arg delegate
4. `sync_walk` legacy route
5. `quest-engine` legacy request alias

지금은 sunset 비권장:

- `sync-walk` 404 cooldown
- `feature-control` 404 cooldown
- `caricature` provider fallback
- `area_references.category = legacy` seed rows 일괄 삭제

## Review Cadence

- `temporary_compat_debt`: 매 backend 배포 또는 앱 릴리즈 시점 검토
- `long_lived_safety_rail`: 분기 1회 검토
- `legacy_data_bridge`: 데이터 배치/카탈로그 개편 시 검토

## Related

- `docs/backend-contract-versioning-policy-v1.md`
- `docs/backend-edge-rpc-deployment-matrix-post-deploy-v1.md`
- `docs/backend-edge-secret-inventory-rotation-runbook-v1.md`
- `docs/backend-request-correlation-idempotency-policy-v1.md`
- `docs/sync-walk-404-fallback-policy-v1.md`
- `docs/area-references-data-governance.md`
- `#417`
- `#427`
- `#479` (Gemini key alias removal completed)

## Validation

- `swift scripts/backend_legacy_fallback_sunset_unit_check.swift`
- `bash scripts/backend_pr_check.sh`
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`
