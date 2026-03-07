# Backend Edge Auth Mode Inventory v1

Date: 2026-03-07  
Issue: #431

## 목적

DogArea backend의 인증 정책을 함수 코드 설명이 아니라 **운영 inventory** 기준으로 고정합니다.

이 문서는 아래를 구분해서 기록합니다.

- Edge Function surface의 auth mode
- 직접 노출되는 RPC / view surface의 auth class
- smoke에서 실제로 검증하는 경로
- 문서와 구현 사이의 잔여 리스크

## Auth Class 정의

### 1. `member_required`

member bearer token이 없으면 호출을 허용하지 않습니다.

규칙:

- empty / malformed bearer: `401`
- anon app bearer: `401`
- invalid member token: `401`
- 인증은 되었지만 대상 소유권이 맞지 않으면 `403`

### 2. `member_or_anon`

member bearer 또는 app/anon bearer를 허용합니다.

규칙:

- member token: `authenticated`
- app/anon bearer: `anon`
- malformed/empty bearer: `401`

### 3. `public_like_restricted`

완전 public은 아니지만, 제한된 읽기 또는 제품 정책상 공개 가능한 surface입니다.

대표 예:

- read-only leaderboard/widget/hotspot RPC
- rollout KPI / feature flag read

### 4. `service_role_internal`

외부 앱 호출이 아니라 운영 작업/내부 정리 경로 전용입니다.

## Edge Function Inventory

| Surface | Auth class | Accepted bearer | External callable | DB privilege pattern | Smoke coverage | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `sync-walk` | `member_required` | member only | yes | service-role proxy write + member subject ownership | `sync-walk.session.member`, invalid-token smoke | 산책 동기화는 member 소유권 필수 |
| `sync-profile` | `member_required` | member only | yes | service-role proxy read/write + `403` user mismatch | `sync-profile.snapshot.member`, `sync-profile.permission.user_mismatch` | `ensureAuthenticatedUserMatch` 사용 |
| `rival-league` | `member_required` | member only | yes | Edge는 member path, underlying leaderboard RPC는 wider read grant | `rival-league.leaderboard.member`, `rival-rpc.compat.member` | Edge/RPC 권한 폭이 다름 |
| `quest-engine` | `member_required` | member only | yes | service-role proxy write/read | `quest-engine.list_active.member`, invalid-token smoke | 진행/클레임은 member 권리경로 |
| `caricature` | `member_required` | member only | yes | service-role proxy storage/db write | member login + edge smoke 기반 | provider fallback만 허용, auth fallback 없음 |
| `nearby-presence` | `member_or_anon` | member, app/anon | yes | service-role proxy + privacy/abuse policy | `nearby-presence.hotspots.app_policy`, `auth_member_401_smoke_check.sh` | anon 허용은 제품 정책 |
| `upload-profile-image` | `member_or_anon` | member, app/anon | yes | service-role proxy storage write | `auth_member_401_smoke_check.sh` | owner binding hardening 후속 필요 |
| `feature-control` | `member_or_anon` | member, app/anon | yes | service-role proxy read/write | `feature-control.flags.anon`, `feature-control.rollout_kpis.anon`, `auth_member_401_smoke_check.sh` | read/write action이 같은 auth class에 묶여 있음 |

## Direct RPC / View Inventory

| Surface | Auth class | Grant | Main caller | Notes |
| --- | --- | --- | --- | --- |
| `rpc_get_nearby_hotspots` | `public_like_restricted` | `anon, authenticated` | `nearby-presence`, hotspot summary path | privacy guard가 결과를 제한 |
| `rpc_get_rival_leaderboard(payload jsonb)` | `public_like_restricted` | `anon, authenticated, service_role` | `rival-league`, widget quest/rival summary compat | Edge는 member_required지만 RPC는 wider read grant |
| `rpc_get_rival_leaderboard(text, integer, timestamptz)` | `public_like_restricted` | `anon, authenticated, service_role` | legacy compat delegate | sunset 대상 compat |
| `rpc_get_widget_hotspot_summary` | `public_like_restricted` | `anon, authenticated, service_role` | hotspot widget | 익명 핫스팟 정책상 anon read 허용 |
| `rpc_get_widget_territory_summary` | `member_required` | `authenticated, service_role` | territory widget | 개인 영역 데이터 |
| `rpc_get_widget_quest_rival_summary(payload jsonb)` | `member_required` | `authenticated, service_role` | quest/rival widget | 개인/리그 결합 데이터 |
| `rpc_get_widget_quest_rival_summary(timestamptz)` | `member_required` | `authenticated, service_role` | compat delegate | compat 유지 중 |
| `rpc_upsert_walk_live_presence(...)` | `member_required` | `authenticated, service_role` | `nearby-presence` live write path | live sharing write는 member 소유권 전제 |
| `rpc_get_walk_live_presence(...)` | `member_required` | `authenticated, service_role` | live presence read path | 공개 지도 전체 공개 경로가 아님 |
| `rpc_cleanup_walk_live_presence(timestamptz)` | `service_role_internal` | `service_role` | cron / cleanup job | 외부 앱 호출 금지 |
| `view_rollout_kpis_24h` | `public_like_restricted` | `anon, authenticated` | `feature-control` | 운영 KPI read |
| `feature_flags` | `public_like_restricted` | `anon, authenticated` | `feature-control` | 읽기 전용 플래그 테이블 |

## Auth Matrix 해석 포인트

### 1. Edge Function과 underlying RPC는 auth 폭이 다를 수 있습니다.

대표 사례:

- `rival-league` Edge surface는 `member_required`
- 하지만 `rpc_get_rival_leaderboard(...)`는 widget/compat/read path 때문에 `anon, authenticated, service_role` grant를 가집니다.

즉, 운영자는 **Edge 함수 정책**과 **DB direct surface grant**를 같은 것으로 보면 안 됩니다.

### 2. `member_or_anon`은 보안 완화가 아니라 제품 정책 surface입니다.

대표 사례:

- `nearby-presence`
- `feature-control`
- `upload-profile-image`

다만 `member_or_anon` surface는 action-level abuse, namespace misuse, owner binding을 별도로 점검해야 합니다.

### 3. `service_role_internal`은 외부 surface와 혼용 금지입니다.

현재 inventory에서 명시적으로 internal-only로 잠겨 있는 대표 surface:

- `rpc_cleanup_walk_live_presence(timestamptz)`

## Smoke / Validation 연결

### Live auth smoke

- `scripts/auth_member_401_smoke_check.sh`

현재 검증:

- `nearby-presence` member/app authorization
- `upload-profile-image` member/app authorization
- `feature-control` member/app authorization
- `rpc_get_rival_leaderboard` member authorization

### Backend smoke matrix

- `docs/supabase-integration-smoke-matrix-v1.md`
- `bash scripts/backend_pr_check.sh`

현재 검증:

- `sync-profile.snapshot.member`
- `sync-walk.session.member`
- `sync-walk.summary.member`
- `rival-league.leaderboard.member`
- widget summary RPC member paths
- invalid token / user mismatch paths

## 문서-구현 대조 결과

### 일치하는 부분

- 고위험 Edge Function 8개는 모두 `edge_auth.ts`를 공통 사용
- `supabase/config.toml`에서 대상 함수는 모두 `verify_jwt = false`
- `sync-profile`만 `403 user mismatch`를 별도 분리
- `nearby-presence`, `upload-profile-image`, `feature-control`은 실제로 `member_or_anon`

### 주의가 필요한 부분

1. `rival-league`는 Edge surface와 RPC direct surface의 auth 폭이 다름
2. `feature-control`은 read action과 write action이 같은 auth class에 묶여 있음
3. `upload-profile-image`는 caller supplied `ownerId`를 그대로 storage object path에 사용

## Residual Risk / Follow-up

### 1. upload-profile-image owner binding

현재 `upload-profile-image`는 `member_or_anon` surface이면서 `ownerId`를 요청 본문에서 받습니다.

운영 해석:

- 문서/구현 mismatch라기보다 **보안 hardening 미완료**
- member path는 auth subject binding을 더 강하게 잠글 필요가 있음
- anon path는 실제 onboarding namespace 전략이 분리되어야 안전함

후속:

- `#466` `[Backend/Security] upload-profile-image owner binding·anon write policy hardening`

### 2. wider RPC grant vs stricter Edge surface

현재는 의도된 compat/read path가 있으므로 즉시 버그로 보지 않습니다.

대표 사례:

- `rpc_get_rival_leaderboard(...)`
- `rpc_get_widget_hotspot_summary`

운영 규칙:

- 이 경로들은 `public_like_restricted`로 해석
- member-only product surface와 혼동 금지

## Validation

- `swift scripts/backend_edge_auth_inventory_unit_check.swift`
- `swift scripts/backend_edge_auth_unification_unit_check.swift`
- `bash scripts/backend_pr_check.sh`
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`
- `DOGAREA_AUTH_SMOKE_ITERATIONS=1 DOGAREA_TEST_EMAIL=... DOGAREA_TEST_PASSWORD=... bash scripts/auth_member_401_smoke_check.sh`

## Related

- `docs/backend-edge-auth-policy-v1.md`
- `docs/backend-high-risk-contract-matrix-v1.md`
- `docs/supabase-integration-smoke-matrix-v1.md`
- `scripts/auth_member_401_smoke_check.sh`
- `supabase/functions/_shared/edge_auth.ts`
