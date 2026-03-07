# Backend Geo Test Seed / Fixture Lifecycle v1

Date: 2026-03-07  
Issue: #440

## 목적

DogArea backend에는 실제 운영 기능 smoke 계정과 QA 전용 geo fixture가 함께 존재합니다.

이 둘을 혼동하면 다음 문제가 생깁니다.

- smoke 계정 결과가 fixture 데이터에 오염됨
- QA용 위치/패턴이 운영 검증 SQL에 섞임
- placeholder migration을 수정해 linked migration 이력을 망침
- production owner scope와 test fixture scope가 뒤섞임

이 문서는 geo test seed / fixture의 분류, reset/regenerate/recenter 기준, 운영 금지사항을 고정합니다.

## 기본 분류

### 1. `integration_smoke_fixture`

실제 Edge/RPC smoke에 쓰는 member 계정입니다.

- 기준 환경변수:
  - `DOGAREA_TEST_EMAIL`
  - `DOGAREA_TEST_PASSWORD`
- 용도:
  - `scripts/run_supabase_smoke_matrix.sh`
  - `scripts/auth_member_401_smoke_check.sh`
  - `scripts/lib/supabase_integration_harness.sh`
- 규칙:
  - geo QA fixture namespace와 분리 유지
  - deterministic contract 검증용 계정으로만 사용

### 2. `qa_geo_fixture`

지도/산책/위치 기반 QA 시나리오에 쓰는 seed namespace입니다.

- 계정 네임스페이스:
  - `dogarea.test.geo%@dogarea.test`
- 주 용도:
  - 지도 시각화
  - 이동 패턴 QA
  - hotspot / summary / 영역 관련 수동 검증
- 특징:
  - 위치 데이터
  - 가짜 프로필/펫/세션/포인트
  - variant별 이동 패턴과 source device 보유

### 3. `historical_migration_anchor`

과거 원격 migration 번호를 보존하기 위한 placeholder migration입니다.

- 대표 내용:
  - `-- Historical placeholder.`
  - `-- This migration version already exists on remote.`
  - `select 1;`
- 규칙:
  - 절대 재편집하지 않음
  - lifecycle의 현재 소스가 아님
  - linked migration 정합성 anchor 역할만 수행

## Inventory

| Migration | Class | Current role | Notes |
| --- | --- | --- | --- |
| `20260226173000_create_area_references_seed.sql` | product_seed | 비교군/영역 catalog seed | geo fixture lifecycle 직접 대상 아님 |
| `20260226181500_seed_test_walk_data.sql` | historical_migration_anchor | 과거 geo seed 번호 anchor | 현재 repo에는 placeholder만 유지 |
| `20260226182500_seed_geo_2km_test_data.sql` | historical_migration_anchor | 과거 2km geo seed anchor | 현재 repo에는 placeholder만 유지 |
| `20260226183500_rename_geo_test_user_and_pet_names.sql` | historical_migration_anchor | 과거 fixture rename anchor | 현재 repo에는 placeholder만 유지 |
| `20260226184500_reduce_geo_test_to_one_pet_per_user.sql` | historical_migration_anchor | 과거 fixture shape anchor | 현재 repo에는 placeholder만 유지 |
| `20260226190000_regenerate_geo_walk_patterns.sql` | historical_migration_anchor | 과거 regenerate anchor | 현재 repo에는 placeholder만 유지 |
| `20260226191500_set_geo_test_profile_photos.sql` | historical_migration_anchor | 과거 profile photo anchor | 현재 repo에는 placeholder만 유지 |
| `20260226192500_set_geo_test_pet_photos.sql` | historical_migration_anchor | 과거 pet photo anchor | 현재 repo에는 placeholder만 유지 |
| `20260227013000_area_references_catalog_seed_upgrade.sql` | product_seed | catalog seed upgrade | geo fixture lifecycle 직접 대상 아님 |
| `20260303173000_seed_geo_test_additional_variants.sql` | qa_geo_fixture | 현재 active geo fixture variant source | 신규 QA variant 추가는 여기 이후 forward-only migration으로 수행 |
| `20260303185000_recenter_geo_test_points_to_yeonsu1dong.sql` | qa_geo_fixture | active geo fixture recenter | 연수1동 기준 좌표 재중심화 |

## 현재 Active QA Variant

현재 활성 QA fixture source는 `20260303173000_seed_geo_test_additional_variants.sql`입니다.

이 migration이 보장하는 현재 variant 축은 다음과 같습니다.

- `source_device` 혼합:
  - `ios`
  - `watchos`
  - `imported`
- in-progress session 존재:
  - `ended_at null`
- 리치 미디어 혼합:
  - `map_image_url`
  - `caricature_url`
- 짧은 3-point polygon variant
- seed namespace:
  - `seed://dogarea/geo2km/v4/%s/micro-short`
  - `seed://dogarea/geo2km/v4/%s/active`

대표 fixture display name:

- `하늘산책가`
- `별빛산책가`
- `노을산책가`
- `새벽산책가`
- `바람산책가`

이 이름과 namespace는 QA fixture의 canonical inventory로 취급합니다.

## Recenter 기준

geo fixture 중심점 변경은 별도 recenter migration으로만 수행합니다.

현재 canonical recenter는 `20260303185000_recenter_geo_test_points_to_yeonsu1dong.sql`입니다.

- 대상 영역:
  - `Yeonsu 1-dong`
  - `연수1동`
- old base:
  - `37.4565, 126.7052`
- new base:
  - `37.421944, 126.682778`
- 적용 대상:
  - `dogarea.test.geo%@dogarea.test`

규칙:

1. recenter는 smoke account에 적용하지 않습니다.
2. recenter는 기존 production owner scope에 적용하지 않습니다.
3. recenter는 새로운 migration으로만 수행하고 기존 migration은 수정하지 않습니다.

## Regenerate 기준

fixture 이동 패턴 변경, variant 추가, session shape 변경은 regenerate 계열 작업입니다.

규칙:

1. regenerate는 항상 forward-only migration으로 수행합니다.
2. 기존 placeholder migration (`historical_migration_anchor`)은 절대 수정하지 않습니다.
3. 기존 variant를 깨는 변경이면 QA 문서와 smoke 영향도를 같이 갱신합니다.
4. smoke member 계정과 geo fixture 계정을 섞지 않습니다.

regenerate가 필요한 예:

- 새로운 source device variant 추가
- polygon point 패턴 교체
- in-progress session 분포 조정
- `map_image_url` / `caricature_url` 샘플 분포 변경

## Reset 기준

로컬에서 fixture lifecycle을 재검증할 때는 reset을 migration replay 관점에서 봅니다.

기본 명령:

```bash
npx --yes supabase db reset
```

linked 상태 확인:

```bash
npx --yes supabase migration list --linked
```

중요:

- `supabase/config.toml`의 `[db.seed]` / `sql_paths = ["./seed.sql"]`는 로컬 seed replay entry입니다.
- geo fixture lifecycle의 canonical source는 linked migration + active QA fixture migration입니다.
- reset 후에도 placeholder migration은 placeholder 그대로여야 합니다.

## 운영 규칙

1. smoke 계정과 geo fixture 계정은 분리 유지합니다.
2. `DOGAREA_TEST_EMAIL` / `DOGAREA_TEST_PASSWORD`는 `integration_smoke_fixture` 전용입니다.
3. `dogarea.test.geo%@dogarea.test` 네임스페이스는 `qa_geo_fixture` 전용입니다.
4. placeholder migration은 수정하지 않습니다.
5. fixture behavior 변경은 새 migration으로만 forward 추가합니다.
6. production owner scope, 실사용자 pet/profile path, fixture owner scope를 혼용하지 않습니다.
7. area reference seed는 product seed이며 geo fixture lifecycle 변경 대상으로 취급하지 않습니다.

## 변경 절차

### QA variant 추가

1. active QA fixture source 이후 번호로 새 migration 생성
2. fixture namespace / source device / summary 영향 문서화
3. smoke 계정과 혼동되지 않는지 검토
4. static check와 backend check 갱신

### Recenter

1. 대상 지역과 좌표 기준 명시
2. `dogarea.test.geo%@dogarea.test` scope 한정
3. shift 전/후 기준점 문서화
4. QA 확인 항목 갱신

### Cleanup

1. fixture-only scope인지 확인
2. smoke 계정에 영향 없는지 확인
3. regenerate 또는 selective delete로 처리
4. rollback보다 roll-forward cleanup을 우선

## 검증

```bash
swift scripts/backend_geo_fixture_lifecycle_unit_check.swift
bash scripts/backend_pr_check.sh
DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh
```

## Related

- `docs/supabase-integration-smoke-matrix-v1.md`
- `docs/supabase-migration.md`
- `docs/backend-deploy-rollback-roll-forward-runbook-v1.md`
- `docs/backend-edge-rpc-deployment-matrix-post-deploy-v1.md`
- `docs/backend-migration-drift-rpc-ci-check-v1.md`
