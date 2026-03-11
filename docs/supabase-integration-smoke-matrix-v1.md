# Supabase Integration Smoke Matrix v1

## 목적

실제 Supabase 프로젝트에 against 하는 최소 smoke/integration 경로를 고정해 backend 리팩터링 회귀를 조기에 찾습니다.

이 문서는 모바일 UI E2E를 대체하지 않습니다. 대신 Edge Function/RPC 계약이 실제 프로젝트에서 살아 있는지 빠르게 확인하는 용도입니다.

## 엔트리포인트

- drift / RPC contract 전용 게이트: `bash scripts/backend_migration_drift_check.sh`
- 구조/문서 연결 체크: `bash scripts/backend_pr_check.sh`
- 실 Supabase smoke 실행: `DOGAREA_RUN_SUPABASE_SMOKE=1 bash scripts/backend_pr_check.sh`
- 직접 matrix 실행: `bash scripts/run_supabase_smoke_matrix.sh`
- member full sweep inventory: `docs/member-supabase-http-full-sweep-v1.md`
- member 5xx zero-budget gate: `docs/member-supabase-http-5xx-zero-budget-gate-v1.md`
- auth surface inventory: `docs/backend-edge-auth-mode-inventory-v1.md`
- deploy inventory / post-deploy 기준: `docs/backend-edge-rpc-deployment-matrix-post-deploy-v1.md`
- geo fixture lifecycle 기준: `docs/backend-geo-test-fixture-lifecycle-v1.md`

## 필수 환경변수

- `DOGAREA_TEST_EMAIL`: member login에 사용할 테스트 계정 이메일
- `DOGAREA_TEST_PASSWORD`: member login에 사용할 테스트 계정 비밀번호

## 선택 환경변수

- `DOGAREA_SUPABASE_CONFIG`: 기본값 `./supabaseConfig.xcconfig`, Supabase URL/anon key를 읽을 xcconfig 경로
- `SUPABASE_URL`: xcconfig 대신 직접 override할 URL
- `SUPABASE_ANON_KEY`: xcconfig 대신 직접 override할 anon key
- `PROJECT_REF`: 출력용 project ref override
- `DOGAREA_SUPABASE_CASE_FILTER`: 정규식 기반 case 필터. 예: `rival|quest-engine`
- `DOGAREA_SUPABASE_SMOKE_TIMEOUT`: curl 요청 타임아웃 초. 기본값 `20`
- `DOGAREA_SUPABASE_SMOKE_SESSION_ID`: `sync-walk` smoke가 재사용할 고정 session id
- `DOGAREA_SUPABASE_SMOKE_PET_ID`: `sync-walk` smoke에 사용할 테스트 반려견 id override. 미지정 시 profile snapshot에서 첫 반려견 id를 읽음
- `DOGAREA_SUPABASE_FOREIGN_USER_ID`: permission mismatch smoke에 사용할 다른 user id

## 현재 smoke matrix

이 matrix는 member 계정 기준 전수조사 sweep을 canonical baseline으로 삼습니다. 원칙은 아래와 같습니다.

- member surface inventory는 `docs/member-supabase-http-full-sweep-v1.md`와 동일해야 합니다.
- live smoke에서 member surface에 대해 server-side `5xx`는 zero-budget입니다.
- business cooldown / validation / policy 거절은 case별 allowlist로만 허용합니다.
- `upload-profile-image`는 disposable smoke 계정/이미지 경로만 사용합니다.
- `caricature`는 비용/외부 provider 호출을 피하기 위해 invalid-request probe만 수행합니다.

### 1. Auth / member authorization 정상 경로

- `auth.member_login`
- `auth.user.member`
- `auth.refresh.member`
- `auth.resend.signup.member_fixture` => `200 | 429`
- `auth.recover.member_fixture` => `200 | 429`
- `signup-email-availability.member`
- `sync-profile.snapshot.member`
- `sync-walk.session.member`
- `sync-walk.session.invalid_payload.missing_pet`
- `sync-walk.session.invalid_payload.invalid_pet`
- `sync-walk.session.invalid_payload.reverse_time`
- `sync-walk.summary.member`
- `nearby-presence.visibility.get.member`
- `nearby-presence.visibility.set.member`
- `nearby-presence.hotspots.member`
- `rival-league.leaderboard.member`
- `widget-territory.summary.member`
- `widget-hotspot.summary.member`
- `widget-quest-rival.summary.member`
- `indoor-mission.summary.member`
- `indoor-mission.record-action.member`
- `indoor-mission.claim.member`
- `indoor-mission.easy-day.member`
- `weather.summary.member`
- `weather.feedback.member`
- `season.summary.member`
- `season.claim.member`
- `quest-engine.list_active.member`
- `feature-control.flags.member`
- `feature-control.flags.anon`
- `feature-control.rollout_kpis.anon`
- `caricature.invalid_request.member`
- `upload-profile-image.member`
- `upload-profile-image.app_policy`

### 2. unauthorized / invalid token 경로

- `sync-profile.snapshot.invalid_token` => `401`
- `sync-walk.summary.invalid_token` => `401`
- `rival-league.leaderboard.invalid_token` => `401`
- `quest-engine.list_active.invalid_token` => `401`

### 3. 권한 정책 / 호환성 경로

- `sync-profile.permission.user_mismatch` => `403`
- `nearby-presence.hotspots.app_policy` => app policy 경로도 canonical payload로 `200`
- `rival-rpc.compat.member` => `/rest/v1/rpc/rpc_get_rival_leaderboard`가 `404` 없이 응답해야 함
- `widget-territory.summary.member` => `/rest/v1/rpc/rpc_get_widget_territory_summary`를 `payload.in_now_ts` wrapper body로 호출했을 때 `200`이어야 함
- `widget-hotspot.summary.member` => `/rest/v1/rpc/rpc_get_widget_hotspot_summary`를 `payload.in_radius_km` / `payload.in_now_ts` wrapper body로 호출했을 때 `200`이어야 함
- `widget-quest-rival.summary.member` => `/rest/v1/rpc/rpc_get_widget_quest_rival_summary`를 `payload.in_now_ts` wrapper body로 호출했을 때 `200`이어야 함
- `upload-profile-image.member_owner_mismatch` => `403`
- `sync-walk.session.invalid_payload.*` => `422`

## 출력 규약

각 케이스는 아래 형식으로 출력합니다.

- `PASS <case-name> status=<code> route=...`
- `FAIL <case-name> expected=<code> actual=<code> route=... body=<snippet>`
- allowlist case는 `FAIL <case-name> allowed=<csv> actual=<code> ...`
- member surface에서 unexpected `5xx`는 `class=server_5xx`를 반드시 포함합니다.

실패 시 어떤 함수/계약에서 깨졌는지 케이스 이름만 보고 바로 식별할 수 있게 유지합니다.

## 운영 가이드

- `feature-control`, `nearby-presence`는 anon/app authorization 정책을 함께 확인합니다.
- `sync-walk` smoke는 고정 session id upsert를 사용해 데이터를 무한 증가시키지 않습니다.
- `sync-walk` smoke는 profile snapshot에서 실제 `pet_id`를 읽어 현재 스키마 제약을 맞춥니다.
- `sync-walk` smoke는 영구 오류 payload(`pet_id` 누락/무효, 시간 역전)가 `422`로 분류되는지도 함께 검증합니다.
- auth resend / recover는 provider cooldown을 고려해 `200 | 429` allowlist로 본다.
- `sync-profile`, `quest-engine`, `rival-league`는 읽기 또는 제한된 contract 호출 위주로 구성합니다.
- widget summary smoke는 read-only RPC만 호출합니다.
- indoor mission / weather / season smoke는 member snapshot fixture를 공유하고, fixture 부족 시 명시적 `fixture_missing`로 실패합니다.
- `upload-profile-image`는 smoke 전용 disposable owner namespace만 허용합니다.
- 실 smoke는 secrets가 필요한 만큼 로컬/CI에서 opt-in으로만 실행합니다.

## CI 연결 포인트

추천 커맨드:

```bash
DOGAREA_RUN_SUPABASE_SMOKE=1 \
DOGAREA_TEST_EMAIL="$DOGAREA_TEST_EMAIL" \
DOGAREA_TEST_PASSWORD="$DOGAREA_TEST_PASSWORD" \
bash scripts/backend_pr_check.sh
```

PR 기본 체크에는 아래 정적 체크를 포함합니다.

- `scripts/supabase_integration_harness_unit_check.swift`
- `scripts/member_supabase_http_inventory_unit_check.swift`
- `scripts/member_supabase_http_zero_budget_gate_unit_check.swift`

secrets가 주입되는 backend job에서만 live smoke를 켭니다.
