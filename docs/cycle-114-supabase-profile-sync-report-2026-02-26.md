# Cycle 114 Report — User/Pet Supabase Profile Sync v1 (2026-02-26)

## 1. Scope
- Target issue: #114
- Goal: `profileMessage`, `breed`, `ageYears`, `gender`를 Supabase 스키마/동기화 경로에 반영

## 2. Documentation First
- Added spec: `docs/userinfo-supabase-sync-v1.md`
- Updated:
  - `docs/supabase-schema-v1.md`
  - `docs/supabase-migration.md`
  - `docs/release-regression-checklist-v1.md`

## 3. Implementation
1. Supabase migration
- Added `supabase/migrations/20260227000000_user_pet_profile_fields_sync.sql`
  - `profiles.profile_message` 추가
  - `pets.breed`, `pets.age_years`, `pets.gender` 추가
  - `gender` 정규화 + `age_years` 범위 정리 백필
  - 제약 추가:
    - `pets_age_years_range_check`
    - `pets_gender_allowed_check`

2. Edge function contract
- Added `supabase/functions/sync-profile/index.ts`
  - action: `sync_profile_stage`, `get_profile_snapshot`
  - stage: `profile`, `pet`
  - payload 검증(age range, gender normalize, pet id/name 필수)
- Added `supabase/functions/sync-profile/README.md`

3. App outbox contract wiring
- Updated `dogArea/Source/UserdefaultSetting.swift`
  - `ProfileSyncOutboxStore`
  - `SupabaseProfileSyncTransport`
  - `ProfileSyncCoordinator`
  - storage key: `sync.profile.outbox.items.v1`
- Updated save flows:
  - `dogArea/Views/SigningView/SigningViewModel.swift`
  - `dogArea/Views/ProfileSettingView/SettingViewModel.swift`
  - 사용자 저장 후 profile sync outbox enqueue + flush

4. Unit check
- Added `scripts/userinfo_supabase_sync_unit_check.swift`

## 4. Unit Tests
- `swift scripts/userinfo_supabase_sync_unit_check.swift` -> PASS
- `swift scripts/userinfo_enhancement_unit_check.swift` -> PASS
- `swift scripts/profile_edit_flow_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS
- `swift scripts/project_stability_unit_check.swift` -> PASS
- `swift scripts/swift_stability_unit_check.swift` -> PASS

## 5. Supabase QA Status
- `npx --yes supabase migration list --local` -> BLOCKED (local DB 미실행: `127.0.0.1:54322 connect refused`)
- `npx --yes supabase migration list --linked` -> BLOCKED (`supabase link` 미설정 워크트리)

## 6. Outcome
- 로컬 확장 프로필 필드가 Supabase 스키마/동기화 계약으로 연결됨
- 앱 저장 시 profile/pet 스냅샷을 outbox 기반으로 원격 전송할 수 있는 경로를 확보
