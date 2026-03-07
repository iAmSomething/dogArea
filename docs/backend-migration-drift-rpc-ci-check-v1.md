# Backend Migration Drift / RPC Contract CI Check v1

## 목적

Supabase migration과 고위험 RPC 계약이 깨졌을 때, 모바일 회귀를 기다리지 않고 backend CI 단계에서 바로 식별합니다.

이 체크는 full semantic SQL 검증이나 모바일 UI E2E를 대체하지 않습니다. 대신 drift와 contract mismatch를 조기에 차단하는 backend 전용 게이트입니다.

## 엔트리포인트

- drift / contract 전용 게이트: `bash scripts/backend_migration_drift_check.sh`
- backend 기본 PR 체크: `bash scripts/backend_pr_check.sh`
- deploy inventory / post-deploy 기준: `docs/backend-edge-rpc-deployment-matrix-post-deploy-v1.md`
- 실 Supabase smoke 포함 backend 체크:

```bash
DOGAREA_RUN_SUPABASE_SMOKE=1 \
DOGAREA_TEST_EMAIL="$DOGAREA_TEST_EMAIL" \
DOGAREA_TEST_PASSWORD="$DOGAREA_TEST_PASSWORD" \
bash scripts/backend_pr_check.sh
```

## 출력 규약

전용 drift entrypoint는 아래 형식으로 출력합니다.

- `RUN`: `[backend-drift] RUN target=<target> check=<check>`
- `PASS`: `[backend-drift] PASS target=<target> check=<check>`
- `FAIL`: `[backend-drift] FAIL target=<target> check=<check> exit=<code>`

핵심 원칙은 실패 로그만 보고도 어느 계약이 깨졌는지 즉시 구분 가능해야 한다는 점입니다.

## 커버리지

| target | static gate | live smoke case |
| --- | --- | --- |
| `rival-leaderboard+widget-quest-rival` | `scripts/rival_rpc_param_compat_unit_check.swift` | `rival-rpc.compat.member`, `widget-quest-rival.summary.member` |
| `sync-walk` | `scripts/backend_migration_drift_rpc_contract_unit_check.swift`, `scripts/sync_walk_404_policy_unit_check.swift` | `sync-walk.session.member`, `sync-walk.summary.member` |
| `widget-territory` | `scripts/territory_status_widget_unit_check.swift` | `widget-territory.summary.member` |
| `widget-hotspot` | `scripts/hotspot_widget_privacy_unit_check.swift` | `widget-hotspot.summary.member` |
| `quest-engine` | `scripts/quest_stage2_engine_unit_check.swift` | `quest-engine.list_active.member` |
| `feature-control` | `scripts/feature_control_404_cooldown_unit_check.swift` | `feature-control.flags.anon`, `feature-control.rollout_kpis.anon` |

## drift 판단 기준

### 1. migration artifact 존재

다음 RPC/함수 정의가 migration에서 계속 보장되어야 합니다.

- `rpc_get_rival_leaderboard(payload jsonb)`
- `rpc_get_widget_quest_rival_summary(payload jsonb)`
- `rpc_get_widget_territory_summary(...)`
- `rpc_get_widget_hotspot_summary(...)`
- `rpc_get_nearby_hotspots(in_center_lat, in_center_lng, in_radius_km, in_now_ts)`
- `rpc_issue_quest_instances`
- `rpc_apply_quest_progress_event`
- `rpc_claim_quest_reward`
- `rpc_transition_quest_status`

### 2. source contract 유지

다음 앱/Edge source contract가 계속 유지되어야 합니다.

- `sync-walk`: `sync_walk_stage`, `get_backfill_summary`
- `quest-engine`: `list_active`, `claim_reward`, `transition_status`
- `feature-control`: `get_flags`, `get_rollout_kpis`

### 3. smoke coverage 유지

고위험 RPC는 live smoke에 이름이 고정돼 있어야 합니다.

- `sync-walk.session.member`
- `sync-walk.summary.member`
- `rival-rpc.compat.member`
- `widget-territory.summary.member`
- `widget-hotspot.summary.member`
- `widget-quest-rival.summary.member`
- `quest-engine.list_active.member`
- `feature-control.flags.anon`
- `feature-control.rollout_kpis.anon`

## 운영 메모

- `sync-walk.session.member` smoke는 member snapshot에서 실제 `pet_id`를 먼저 읽어 payload에 주입합니다.
- widget summary smoke는 read-only RPC만 호출합니다.
- drift gate는 빠른 실패가 목적이므로, 하나의 타깃이 깨지면 해당 타깃 이름과 check 이름이 그대로 로그에 남아야 합니다.
