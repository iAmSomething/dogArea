# Backend High-risk Contract Matrix v1

Date: 2026-03-07  
Issue: #417

이 문서는 고위험 Edge Function / RPC가 현재 어떤 canonical contract와 compat 경로를 가지는지 정리합니다.

## Matrix

| Surface | Canonical request/signature | Current compat / fallback | Response envelope status | Validation | Follow-up |
| --- | --- | --- | --- | --- | --- |
| `sync-walk` | Edge POST JSON + `action`/`stage`/`payload`, route `sync-walk` | legacy route `sync_walk` 404 fallback 정책 유지 | 문서 기준 `ok/version/request_id` target, runtime 전면 rollout은 후속 | `docs/sync-walk-404-fallback-policy-v1.md`, `scripts/sync_walk_404_policy_unit_check.swift`, smoke matrix route probe | `#424`, `#437` |
| `nearby-presence` | Edge POST JSON + `action`, hotspot RPC latest signature `in_center_lat/in_center_lng/in_radius_km/in_now_ts` | `rpc_get_nearby_hotspots(center_lat, center_lng, radius_km, now_ts)` legacy signature fallback | 문서 기준 `ok/code/message/request_id/version` target, runtime rollout은 후속 | source compat helper, smoke matrix `nearby-presence.hotspots.app_policy` | `#425`, `#431`, `#437` |
| `rival-league` | Edge POST JSON + `action`, leaderboard RPC canonical `rpc_get_rival_leaderboard(payload jsonb)` | 3-arg `rpc_get_rival_leaderboard(period_type, top_n, now_ts)` delegate 유지 | 문서 기준 envelope target, leaderboard body top-level 유지 | `scripts/rival_rpc_param_compat_unit_check.swift`, smoke matrix `rival-rpc.compat.member` | `#419`, `#437` |
| `quest-engine` | Edge POST JSON + `action` + optional `request_id` / `payload` | legacy camelCase request fields 일부 허용 | 문서 기준 envelope target, action payload shape는 유지 | smoke matrix `quest-engine.list_active.member`, static contract doc check | `#419`, `#438` |
| `rpc_get_widget_quest_rival_summary` | `payload jsonb` wrapper canonical | `timestamptz` positional signature compat 유지 | wrapper는 canonical envelope, positional은 legacy top-level 유지 | `scripts/rival_rpc_param_compat_unit_check.swift`, `docs/widget-summary-rpc-common-response-model-v1.md` | `#429`, `#437`, `#459` |
| `rpc_get_widget_territory_summary` | `payload jsonb` wrapper canonical | `timestamptz` positional signature compat 유지 | wrapper는 canonical envelope, positional은 legacy top-level 유지 | migration static check + policy doc, `docs/widget-summary-rpc-common-response-model-v1.md` | `#429`, `#459` |
| `rpc_get_widget_hotspot_summary` | `payload jsonb` wrapper canonical | positional `(radius_km, now_ts)` compat + 내부 `rpc_get_nearby_hotspots` positional 의존 | wrapper는 canonical envelope, positional은 legacy top-level 유지 | migration static check + policy doc, `docs/widget-summary-rpc-common-response-model-v1.md` | `#429`, `#437`, `#459` |

## Canonical Envelope 적용 원칙

고위험 Edge Function은 성공/실패 모두 아래 공통 메타를 목표로 합니다.

- success: `ok`, `version`, `request_id`
- error: `ok`, `error`, `code`, `message`, `request_id`, `version`

단, 기존 앱 파서를 깨지 않도록 도메인 키(`leaderboard`, `quests`, `summary`, `presence`, `hotspots`)는 top-level 유지가 원칙입니다.

## RPC Parameter Rule Summary

- 앱/REST 직접 호출: `payload jsonb` wrapper canonical
- 내부 delegate/legacy: positional arg 허용
- wrapper / delegate는 최대 2계층까지만 허용

정리 대상:

- `rpc_get_rival_leaderboard(payload jsonb)`는 이미 canonical
- `rpc_get_widget_quest_rival_summary(payload jsonb)`도 canonical
- `rpc_get_widget_territory_summary(payload jsonb)` / `rpc_get_widget_hotspot_summary(payload jsonb)`도 canonical
- `rpc_get_nearby_hotspots`는 latest `in_*` 시그니처 우선, legacy positional fallback 유지

## Sunset Rule

아래 조건을 만족하기 전까지 compat 제거 금지:

1. 문서 업데이트 완료
2. smoke/static check 갱신 완료
3. post-deploy smoke 2회 연속 통과
4. 최소 2개 앱 릴리즈 또는 14일 경과

## Validation

- `swift scripts/backend_contract_versioning_unit_check.swift`
- `bash scripts/backend_pr_check.sh`
