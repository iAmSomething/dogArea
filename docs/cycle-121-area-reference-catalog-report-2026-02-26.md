# Cycle 121 Report — Area Reference Catalog & Seed Upgrade v1 (2026-02-26)

## 1. Scope
- Target issue: #121
- Goal: `area_references`를 카탈로그 기반 운영 구조로 확장하고 비교군 시드를 확대

## 2. Documentation First
- Updated `docs/supabase-schema-v1.md`
  - `area_reference_catalogs` 엔티티 추가
  - `area_references.catalog_id/display_order/is_featured` 반영
- Updated `docs/supabase-migration.md`
  - 카탈로그/시드 정합성 검증 SQL(5.6) 추가
- Updated `docs/release-regression-checklist-v1.md`
  - 카탈로그 구조 회귀 체크 항목 추가

## 3. Implementation
1. Migration
- Added `supabase/migrations/20260227013000_area_references_catalog_seed_upgrade.sql`
  - `area_reference_catalogs` 테이블 추가
  - `area_references`에 `catalog_id`, `display_order`, `is_featured` 컬럼 추가
  - 중복 `reference_name` 정리 + unique index + catalog FK 추가
  - RLS/정책/인덱스/updated_at trigger 확장
  - 국내 지자체/해외 도시공원/국립공원 시드 upsert(카탈로그 기반)

2. Unit check
- Added `scripts/area_reference_catalog_seed_unit_check.swift`

## 4. Unit Tests
- `swift scripts/area_reference_catalog_seed_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS
- `swift scripts/supabase_ops_hardening_unit_check.swift` -> PASS
- `swift scripts/project_stability_unit_check.swift` -> PASS
- `swift scripts/swift_stability_unit_check.swift` -> PASS

## 5. Outcome
- 비교군 데이터가 카탈로그/정렬/featured 기반으로 운영 가능한 구조가 됨
- 시드 업서트 기반으로 중복 없이 데이터 확장이 가능해짐

## 6. Supabase QA Status
- `npx --yes supabase migration list --local` -> BLOCKED (local DB 미실행)
- `npx --yes supabase migration list --linked` -> BLOCKED (`supabase link` 미설정 워크트리)
