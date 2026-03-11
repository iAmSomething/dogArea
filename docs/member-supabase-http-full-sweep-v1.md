# Member Supabase HTTP Full Sweep v1

- Issue: #732
- Relates to: #416, #420, #733

## 목적
- member 계정이 있는 조건에서 앱이 실제 호출하는 Supabase HTTP surface를 빠짐없이 점검한다.
- 대표 경로 smoke가 아니라 code inventory 기준 full sweep을 고정한다.
- 향후 endpoint drift가 생기면 문서/runner/static check가 함께 깨지게 만든다.

## Canonical Runner
- live runner: `bash scripts/run_supabase_smoke_matrix.sh`
- backend entrypoint: `DOGAREA_RUN_SUPABASE_SMOKE=1 DOGAREA_TEST_EMAIL=... DOGAREA_TEST_PASSWORD=... bash scripts/backend_pr_check.sh`
- drift check: `swift scripts/member_supabase_http_inventory_unit_check.swift`

## Code Inventory

### Auth
- `auth/v1/user`
- `auth/v1/token?grant_type=refresh_token`
- `auth/v1/resend`
- `auth/v1/recover`

### Edge Functions
- `functions/v1/sync-profile`
- `functions/v1/sync-walk`
- `functions/v1/nearby-presence`
- `functions/v1/quest-engine`
- `functions/v1/feature-control`
- `functions/v1/caricature`
- `functions/v1/upload-profile-image`

### REST RPC
- `rpc/rpc_check_signup_email_availability`
- `rpc/rpc_get_rival_leaderboard`
- `rpc/rpc_get_widget_quest_rival_summary`
- `rpc/rpc_get_indoor_mission_summary`
- `rpc/rpc_record_indoor_mission_action`
- `rpc/rpc_claim_indoor_mission_reward`
- `rpc/rpc_activate_indoor_easy_day`
- `rpc/rpc_get_widget_territory_summary`
- `rpc/rpc_get_widget_hotspot_summary`
- `rpc/rpc_get_weather_replacement_summary`
- `rpc/rpc_submit_weather_feedback`
- `rpc/rpc_get_owner_season_summary`
- `rpc/rpc_claim_season_reward`

## Sweep Coverage Rule
- route inventory에 있는 endpoint는 runner에 최소 1개 이상 case가 있어야 한다.
- member 토큰이 canonical인 route는 member case를 둔다.
- app/anon policy가 canonical인 route는 app policy case를 함께 둔다.
- mutation route는 가능하면 실제 fixture를 사용하고, 불가하면 명시적 invalid-request case로 route health를 본다.

## Fixture / Env Rules
- 필수 env
  - `DOGAREA_TEST_EMAIL`
  - `DOGAREA_TEST_PASSWORD`
- profile snapshot fixture
  - smoke member는 `sync-profile get_profile_snapshot`에서 최소 1개 반려견을 반환해야 한다.
  - `rpc_get_indoor_mission_summary`, `sync-walk session`, `caricature invalid request`는 이 반려견 id를 사용한다.
- upload fixture
  - `upload-profile-image.member`는 disposable smoke account를 사용해야 한다.
  - smoke는 1x1 PNG를 업로드하므로 프로필 이미지가 덮어써질 수 있다.
- mail fixture
  - `auth/v1/resend`, `auth/v1/recover`는 실제 테스트 메일 계정에 영향을 줄 수 있다.
  - SMTP/provider cooldown으로 `429`가 발생할 수 있다.
- indoor mission fixture
  - summary 호출은 `in_base_risk_level=severe` fixture를 사용해 최소 1개 미션을 생성해야 한다.
  - summary 응답은 PostgREST row 배열 기준으로 `0.missions.0.missionInstanceId`와 `0.day_key`가 파생돼야 한다.
  - 없으면 fixture 불충분으로 간주하고 sweep 실패로 처리한다.
- season fixture
  - `rpc_get_owner_season_summary`는 `current_week_key`를 반환해야 한다.

## Case Naming Rule
- 형식: `<surface>.<operation>.<policy or outcome>`
- 예시
  - `auth.user.member`
  - `nearby-presence.visibility.get.member`
  - `upload-profile-image.member_owner_mismatch`
  - `indoor-mission.record-action.member`

## Drift Guard
- source inventory, smoke runner, 문서가 모두 같은 route set을 가져야 한다.
- route가 code에 새로 생기면 아래 3개가 같이 갱신되어야 한다.
  - 이 문서
  - `scripts/run_supabase_smoke_matrix.sh`
  - `scripts/member_supabase_http_inventory_unit_check.swift`
