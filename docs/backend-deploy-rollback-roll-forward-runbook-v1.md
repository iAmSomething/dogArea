# Backend Deploy Rollback / Roll-Forward Runbook v1

Date: 2026-03-07  
Issue: #439

## 목적

backend 장애가 났을 때 항상 rollback이 정답은 아닙니다.

DogArea의 backend는 다음이 섞여 있습니다.

- Supabase migration / RPC signature
- Edge Function deploy / route / env
- seed / test fixture

이 문서는 어떤 경우에 rollback을 택하고, 어떤 경우에 roll-forward를 택해야 하는지 운영 기준을 고정합니다.

## 기본 원칙

1. **migration은 destructive rollback을 기본 선택지로 두지 않습니다.**
2. route 누락, env 누락, 함수 미배포는 보통 rollback보다 **roll-forward redeploy/fix**가 우선입니다.
3. test fixture 오염은 production schema rollback이 아니라 **fixture 정리/regenerate**로 다룹니다.
4. 사용자 데이터 손상 가능성이 있으면 먼저 write를 멈추고, 승인된 복구 절차로 들어갑니다.

## Decision Matrix

| Failure type | Default action | Why | Rollback allowed when | First checks |
| --- | --- | --- | --- | --- |
| RPC signature mismatch / migration drift | `roll-forward` | wrapper/delegate/selective fix migration이 더 안전함 | 신규 migration이 아직 실질 write를 만들지 않았고, 명확한 selective revert가 가능한 경우 | `migration list --linked`, drift gate, affected RPC smoke |
| Edge Function route `404` / function not deployed | `roll-forward` | canonical route redeploy가 가장 빠름 | 이전 함수 버전이 즉시 되살릴 수 있고 현재 버전이 구조적으로 잘못된 경우 | deploy matrix, smoke matrix, function route name |
| Edge Function env/auth misconfig | `roll-forward` | secret/env/config 수정 후 redeploy가 정석 | 이전 deploy artifact가 정상이고 현재 env change만 되돌리면 즉시 복구되는 경우 | `SERVER_MISCONFIGURED`, auth smoke, secret inventory |
| rollout/feature-control misdeployment | `roll-forward` 또는 feature flag kill | 데이터 구조 rollback보다 ops flag 조정이 안전함 | 이전 flag state가 명확하고 즉시 복구 가능한 경우 | rollout KPI, feature-control smoke |
| seed/test fixture contamination | `roll-forward cleanup` | test data 재생성/비활성화가 안전함 | fixture-only scope가 명확하고 prior known-good snapshot이 있을 때 | fixture inventory, affected test users/pets, QA smoke |
| user data corruption | `write freeze + approved restore path` | 무분별한 rollback이 2차 손상을 만들 수 있음 | 운영 승인 + snapshot restore plan이 준비된 경우만 | owner stats, audit logs, storage/object scope |

## Core Commands

migration / linked state:

```bash
npx --yes supabase migration list --local
npx --yes supabase migration list --linked
npx --yes supabase db push --linked --dry-run
```

backend verification:

```bash
bash scripts/backend_pr_check.sh
```

live smoke:

```bash
DOGAREA_RUN_SUPABASE_SMOKE=1 \
DOGAREA_TEST_EMAIL=... \
DOGAREA_TEST_PASSWORD=... \
bash scripts/backend_pr_check.sh
```

auth/member-app surface:

```bash
DOGAREA_AUTH_SMOKE_ITERATIONS=1 \
DOGAREA_TEST_EMAIL=... \
DOGAREA_TEST_PASSWORD=... \
bash scripts/auth_member_401_smoke_check.sh
```

## Scenario Playbooks

### A. RPC signature mismatch after migration

대표 증상:

- `/rest/v1/rpc/...` 가 `404` 또는 `500`
- Edge Function은 살아 있지만 underlying RPC에서 실패
- widget summary / rival RPC compat가 깨짐

기본 선택:

- `roll-forward`

절차:

1. `bash scripts/backend_migration_drift_check.sh`
2. `npx --yes supabase migration list --linked`
3. 누락된 wrapper/delegate/selective compat migration 식별
4. destructive revert 대신 **forward compat migration** 작성
5. `bash scripts/backend_pr_check.sh`
6. `DOGAREA_RUN_SUPABASE_SMOKE=1 ... bash scripts/backend_pr_check.sh`

rollback을 고르는 예외:

- 최신 migration이 아직 실제 write를 만들지 않았고
- 이전 상태로 되돌리는 migration이 명확하며
- selective revert가 데이터 손실 없이 가능한 경우

### B. Edge Function route 404 / deploy mismatch

대표 증상:

- `/functions/v1/...` `404`
- canonical route는 없고 legacy fallback만 동작하거나 둘 다 실패

기본 선택:

- `roll-forward`

절차:

1. deploy matrix에서 canonical route 확인
2. `bash scripts/backend_pr_check.sh`
3. live smoke로 해당 route만 먼저 재검증
4. 누락 함수만 redeploy
5. post-deploy Tier 0 smoke 재실행

rollback을 고르는 예외:

- 방금 배포한 함수 bundle이 전반적으로 깨졌고
- 직전 known-good artifact로 되돌리는 것이 더 빠르며
- route/env/contract가 직전 버전과 호환되는 경우

### C. Edge env / secret misconfiguration

대표 증상:

- `SERVER_MISCONFIGURED`
- member는 붙는데 특정 함수만 `500`
- service-role proxy 함수만 실패

기본 선택:

- `roll-forward`

절차:

1. `docs/backend-edge-secret-inventory-rotation-runbook-v1.md`에서 필요한 env 확인
2. secret/env 값을 secure store와 hosted env에서 비교
3. 필요한 함수만 재배포
4. auth smoke + relevant function smoke 재실행

주의:

- secret incident가 아니라 단순 누락이면 불필요한 전면 rotate를 하지 않습니다.

### D. Seed / test fixture contamination

대표 증상:

- geo test 사용자/펫/포인트가 QA 결과를 오염
- smoke 계정과 fixture가 섞임
- test variant 재생성 후 예상치 못한 위치/패턴이 보임

대상 migration 예:

- `20260226181500_seed_test_walk_data.sql`
- `20260226182500_seed_geo_2km_test_data.sql`
- `20260226183500_rename_geo_test_user_and_pet_names.sql`
- `20260226190000_regenerate_geo_walk_patterns.sql`
- `20260303173000_seed_geo_test_additional_variants.sql`
- `20260303185000_recenter_geo_test_points_to_yeonsu1dong.sql`

기본 선택:

- `roll-forward cleanup`

절차:

1. fixture scope가 production owner data와 분리되는지 확인
2. `#440` 기준 fixture lifecycle 문서/목적 분류 확인
3. selective cleanup 또는 regenerate/recenter 수행
4. smoke account와 fixture account를 다시 분리 확인
5. smoke matrix 재실행

rollback을 고르는 예외:

- fixture-only 변경이고
- prior known-good seed snapshot이 있으며
- 해당 rollback이 production user data를 건드리지 않는 것이 명확한 경우

### E. User data corruption suspicion

대표 증상:

- owner stats 급변
- walk/session/pet/profiles 정합성 붕괴
- 잘못된 write path가 실사용자 데이터에 반영

기본 선택:

- `rollback`보다 먼저 `write freeze + assessment`

절차:

1. 신규 write 차단 또는 feature flag kill
2. 영향 범위 SQL 확인
3. audit/log/snapshot 확보
4. 운영 승인 후 selective restore 또는 snapshot restore
5. 복구 후 smoke + product QA

금지:

- 원인 미확인 상태에서 blind delete
- production 데이터를 test fixture rollback처럼 취급

## Rollback vs Roll-Forward Heuristics

roll-forward가 더 적합한 경우:

- compat wrapper / delegate / env fix로 좁게 해결 가능
- schema 자체를 뒤집지 않아도 됨
- function route 또는 secret만 잘못됨

rollback이 더 적합한 경우:

- 현재 배포가 구조적으로 잘못되어 즉시 복구가 안 됨
- 직전 known-good 상태가 명확함
- 되돌림이 data loss 없이 가능함
- 운영 승인과 복구 범위가 명시됨

## Mandatory Evidence Before Decision

rollback이나 roll-forward를 고르기 전에 최소한 아래 4개는 남깁니다.

1. failing surface
2. current linked migration state
3. smoke result
4. data loss risk 판단

없으면 판단을 서두르지 않습니다.

## Related

- `docs/supabase-migration.md`
- `docs/backend-edge-rpc-deployment-matrix-post-deploy-v1.md`
- `docs/backend-edge-incident-runbook-v1.md`
- `docs/backend-edge-secret-inventory-rotation-runbook-v1.md`
- `docs/backend-legacy-fallback-compat-sunset-plan-v1.md`
- `docs/supabase-schema-v1.md`
- `#440`

## Validation

- `swift scripts/backend_deploy_rollback_runbook_unit_check.swift`
- `bash scripts/backend_pr_check.sh`
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`

