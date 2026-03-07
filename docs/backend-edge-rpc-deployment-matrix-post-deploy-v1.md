# Backend Edge Function / RPC Deployment Matrix & Post-Deploy Verification v1

Date: 2026-03-07  
Issue: #436

## 목적

backend 배포 이후에는 "무엇을 deploy했는가"보다 "어떤 앱 경로가 지금 깨질 수 있는가"를 바로 판단할 수 있어야 합니다.

이 문서는 아래를 한 곳에 고정합니다.

- Edge Function / 핵심 RPC inventory
- deploy 대상과 앱 핵심 경로 매핑
- post-deploy에서 바로 확인해야 하는 smoke case
- `404` / `401` / contract mismatch가 났을 때의 1차 운영 행동

이 문서는 전체 앱 QA를 대체하지 않습니다. 대신 backend deploy 직후의 좁고 빠른 운영 검증 기준입니다.

## Entry Points

- 구조/문서/정적 체크: `bash scripts/backend_pr_check.sh`
- migration drift / RPC contract 게이트: `bash scripts/backend_migration_drift_check.sh`
- live Supabase smoke matrix: `bash scripts/run_supabase_smoke_matrix.sh`
- full backend post-deploy smoke:

```bash
DOGAREA_RUN_SUPABASE_SMOKE=1 \
DOGAREA_TEST_EMAIL="$DOGAREA_TEST_EMAIL" \
DOGAREA_TEST_PASSWORD="$DOGAREA_TEST_PASSWORD" \
bash scripts/backend_pr_check.sh
```

## Inventory Matrix

| Surface | Type | Canonical route / name | Primary app dependency | Deploy trigger examples | Post-deploy smoke case | Expected result | If failed first suspicion |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `sync-profile` | Edge Function | `/functions/v1/sync-profile` | 로그인 직후 profile snapshot, 설정/프로필 복구 | auth/session/profile schema 변경 | `sync-profile.snapshot.member` | `200` | auth helper / function route / member session path |
| `sync-profile` permission guard | Edge Function | `/functions/v1/sync-profile` | 타 사용자 데이터 차단 | profile authorization 변경 | `sync-profile.permission.user_mismatch` | `403` | permission check drift |
| `sync-walk` | Edge Function | `/functions/v1/sync-walk` | 산책 업로드, 홈 이관, backfill summary | walk sync stage / outbox / route fallback 변경 | `sync-walk.session.member`, `sync-walk.summary.member` | `200` | route 404, action contract drift, payload schema mismatch |
| `nearby-presence` | Edge Function | `/functions/v1/nearby-presence` | 라이벌 탭 hotspot, 익명 위치 공유 | privacy guard / presence write / hotspot RPC compat 변경 | `nearby-presence.hotspots.app_policy` | `401`이 아니어야 함 | anon auth policy / service-role path / hotspot RPC compat |
| `rival-league` | Edge Function | `/functions/v1/rival-league` | 라이벌 탭 leaderboard fetch | leaderboard action / auth / ranking source 변경 | `rival-league.leaderboard.member` | `200` | member auth / edge action dispatch drift |
| `rpc_get_rival_leaderboard(payload jsonb)` | RPC | `/rest/v1/rpc/rpc_get_rival_leaderboard` | 라이벌 랭킹 canonical RPC | RPC signature / compat wrapper 변경 | `rival-rpc.compat.member` | `200` | PostgREST wrapper 누락, signature drift |
| `quest-engine` | Edge Function | `/functions/v1/quest-engine` | 퀘스트 보드/활성 목록/보상 흐름 | quest action contract / server authority 변경 | `quest-engine.list_active.member` | `200` | action registry drift / auth regression |
| `feature-control` | Edge Function | `/functions/v1/feature-control` | rollout flags, KPI surface, feature gating | flag schema / rollout KPI payload 변경 | `feature-control.flags.anon`, `feature-control.rollout_kpis.anon` | `200` | anon auth regression / function route missing |
| `rpc_get_widget_territory_summary` | RPC | `/rest/v1/rpc/rpc_get_widget_territory_summary` | Territory widget summary | widget summary schema / territory aggregation 변경 | `widget-territory.summary.member` | `200` | RPC migration drift / grant regression |
| `rpc_get_widget_hotspot_summary` | RPC | `/rest/v1/rpc/rpc_get_widget_hotspot_summary` | Hotspot widget summary | hotspot summary / privacy policy / nearby RPC delegate 변경 | `widget-hotspot.summary.member` | `200` | delegate RPC drift / privacy contract mismatch |
| `rpc_get_widget_quest_rival_summary(payload jsonb)` | RPC | `/rest/v1/rpc/rpc_get_widget_quest_rival_summary` | Quest/Rival widget summary | rival RPC compat / widget summary envelope 변경 | `widget-quest-rival.summary.member` | `200` | payload wrapper drift / upstream rival RPC failure |
| `upload-profile-image` | Edge Function | `/functions/v1/upload-profile-image` | 프로필 편집 이미지 업로드 | storage policy / owner binding / public URL path 변경 | `upload_profile member=200 app=200 member_mismatch=403` from `auth_member_401_smoke_check.sh` | member/app `200`, mismatch `403` | service-role/storage path regression / owner binding drift / anon namespace drift |
| `caricature` | Edge Function | `/functions/v1/caricature` | 캐리커처 생성 | provider key / storage upload / model router 변경 | targeted manual smoke only | provider-dependent | provider key missing / storage upload failure |

## Post-Deploy Priority

### Tier 0: deploy 직후 무조건 확인

- `sync-profile.snapshot.member`
- `sync-walk.session.member`
- `sync-walk.summary.member`
- `nearby-presence.hotspots.app_policy`
- `rival-rpc.compat.member`
- `quest-engine.list_active.member`
- `feature-control.flags.anon`
- `feature-control.rollout_kpis.anon`

이 8개는 최근 실제 장애 패턴과 가장 직접적으로 연결됩니다.

### Tier 1: widget / leaderboard / adjacent surface

- `rival-league.leaderboard.member`
- `widget-territory.summary.member`
- `widget-hotspot.summary.member`
- `widget-quest-rival.summary.member`
- `sync-profile.permission.user_mismatch`

### Tier 2: feature-specific manual verification

- `upload-profile-image`
- `caricature`

이 두 개는 live matrix 기본 세트에 묶기보다 feature rollout 또는 incident 시 별도 smoke로 확인합니다.

## Failure Pattern -> First Action

| Symptom | First action |
| --- | --- |
| 함수 route `404` | Edge deploy 대상 함수명이 canonical route와 일치하는지 확인 (`sync-walk` vs legacy fallback 포함) |
| member route `401` | `verify_jwt`, `edge_auth.ts`, member token 발급 상태, anon key/apikey header 경로 확인 |
| anon/app route `401` | anon bearer 허용 정책과 `SUPABASE_ANON_KEY` header wiring 확인 |
| RPC `404` | migration drift / wrapper function / grant 누락 확인 |
| RPC `500` | upstream delegate RPC signature, payload wrapper, recent migration diff 확인 |
| widget summary만 실패 | widget RPC migration/grant와 common response model 변경 여부 우선 확인 |
| `feature-control`만 실패 | rollout payload shape와 function route 배포 여부 확인 |

## Recommended Deploy Flow

### 1. deploy scope 확정

배포 전에 아래 중 어떤 그룹인지 먼저 표시합니다.

- Edge Function only
- RPC / migration only
- Edge + RPC 동시
- widget summary contract 포함

### 2. matrix에서 영향 surface 표시

최소한 아래를 기록합니다.

- touched surface
- expected smoke cases
- manual follow-up이 필요한 feature

### 3. post-deploy smoke 실행

권장:

```bash
DOGAREA_RUN_SUPABASE_SMOKE=1 \
DOGAREA_TEST_EMAIL=... \
DOGAREA_TEST_PASSWORD=... \
bash scripts/backend_pr_check.sh
```

빠른 개별 실행:

```bash
bash scripts/run_supabase_smoke_matrix.sh
```

### 4. failure triage

- 함수 계열이면 route / auth / action name 먼저 본다
- RPC 계열이면 migration drift / wrapper / grant를 먼저 본다
- widget 계열이면 upstream RPC와 envelope compat을 같이 본다

### 5. deploy completion note

배포 완료 기록에는 아래를 남깁니다.

- deployed surfaces
- smoke command
- failing/waived cases
- rollback 또는 follow-up 이슈 번호

## Source of Truth

- live smoke case naming: `scripts/run_supabase_smoke_matrix.sh`
- member/app auth smoke: `scripts/auth_member_401_smoke_check.sh`
- drift/static gate: `scripts/backend_migration_drift_check.sh`
- rollback / roll-forward runbook: `docs/backend-deploy-rollback-roll-forward-runbook-v1.md`
- fallback/compat sunset 기준: `docs/backend-legacy-fallback-compat-sunset-plan-v1.md`
- sync-walk 404 ops nuance: `docs/sync-walk-404-fallback-policy-v1.md`
- auth mode boundary: `docs/backend-edge-auth-mode-inventory-v1.md`
- widget contract shape: `docs/widget-summary-rpc-common-response-model-v1.md`

## Validation

- `swift scripts/backend_edge_rpc_deploy_matrix_unit_check.swift`
- `bash scripts/backend_pr_check.sh`
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`
