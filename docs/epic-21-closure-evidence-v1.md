# Epic #21 Closure Evidence Snapshot (2026-03-09, Resolved)

- 대상 에픽: #21 `[Epic] 2026 안정화/고도화: Supabase 전환 + 다견 + watchOS + 캐리커처`
- 근거 수집 이슈: #412 `[Epic/QA] #21 종료를 위한 운영 검증·보안 근거 수집`
- 해결 이슈: #595 `[Epic/QA] #21 closure blocker: linked migration rollout 재개 및 stats evidence 재수집`

## 1. 목적

`#21`의 남은 DoD 3개를 2026-03-09 기준으로 재점검하고, linked rollout 및 SQL parity blocker를 해소한 뒤 에픽 종료 가능 여부를 다시 확정한다.

## 2. 실행 기준

- 기준 브랜치: `main`에서 분기한 `codex/epic-21-evidence`
- 실행 명령:
  - `bash scripts/backend_pr_check.sh`
  - `bash scripts/ios_pr_check.sh`
  - `swift scripts/security_key_exposure_unit_check.swift`
  - `npx --yes supabase migration list --linked`
  - `npx --yes supabase db push --linked`
- 연계 문서:
  - `docs/supabase-migration.md`
  - `docs/coredata-supabase-backfill.md`
  - `docs/release-regression-checklist-v1.md`
  - `docs/release-regression-report-2026-02-26.md`
  - `docs/cycle-22-supabase-ops-report-2026-02-26.md`
  - `docs/cycle-23-coredata-supabase-backfill-report-2026-02-26.md`

## 3. DoD 판정

| DoD | 상태 | 근거 | 메모 |
| --- | --- | --- | --- |
| 하위 이슈 DoD 완료 + main 병합 기준 빌드/배포/회귀 통과 | `PASS` | `bash scripts/backend_pr_check.sh` PASS, `DOGAREA_RUN_SUPABASE_SMOKE=1 ... bash scripts/backend_pr_check.sh` PASS, `bash scripts/ios_pr_check.sh` PASS, `npx --yes supabase migration list --linked` local==remote | linked rollout blocker였던 `20260309043000_realtime_retention_cleanup_rollout.sql` 적용 완료. |
| Supabase 운영 검증 SQL 결과와 앱 통계(산책수/시간/면적) 합치 | `PASS` | `sync-walk action=get_backfill_summary`와 `view_owner_walk_stats` 비교 결과 `session_count / point_count / total_area_m2 / total_duration_sec` 전부 일치 | `view_owner_walk_stats`에 `total_duration_sec`를 추가하는 migration 적용 완료. |
| 서비스 롤 키/모델 API 키 앱 노출 0건 | `PASS` | `swift scripts/security_key_exposure_unit_check.swift` PASS | 저장소 기준 하드코딩 시크릿 노출 0건 확인. |

## 4. linked Supabase 배포 상태

### 4.1 migration push 결과

`npx --yes supabase db push --linked` 재실행 결과:

- `20260309043000_realtime_retention_cleanup_rollout.sql` 적용 성공
- `20260309044338_owner_walk_stats_duration_parity.sql` 적용 성공

### 4.2 migration list 결과

`npx --yes supabase migration list --linked` 재실행 결과:

- local == remote
- drift 0건

즉, linked DB rollout blocker는 해소됐다.

## 5. Supabase SQL vs 앱 통계 근거

### 5.1 앱 측 summary 경로

앱/백필 검증은 `sync-walk`의 `get_backfill_summary`를 사용한다.

관련 근거:

- `docs/coredata-supabase-backfill.md`
- `docs/cycle-23-coredata-supabase-backfill-report-2026-02-26.md`

이 경로는 `GuestDataUpgradeReport`에 아래 필드를 저장한다.

- `remoteSessionCount`
- `remotePointCount`
- `remoteTotalAreaM2`
- `remoteTotalDurationSec`
- `validationPassed`

### 5.2 2026-03-09 비교 결과

테스트 member 계정으로 실제 원격 비교를 수행한 결과:

- `get_backfill_summary`:
  - `session_count = 2`
  - `point_count = 9`
  - `total_area_m2 = 12.5`
  - `total_duration_sec = 1357`
- `view_owner_walk_stats`:
  - `session_count = 2`
  - `point_count = 9`
  - `total_area_m2 = 12.5`
  - `total_duration_sec = 1357`

판정:

- `session_count / point_count / total_area_m2 / total_duration_sec` 모두 SQL 뷰와 app-facing summary가 일치
- `산책수/시간/면적`을 포함한 DoD는 충족됨

### 5.3 남은 작업

없음. `#595` 범위는 모두 해소됐다.

## 6. 보안 점검 근거

2026-03-09 실행 결과:

- 명령: `swift scripts/security_key_exposure_unit_check.swift`
- 결과: `PASS`

검사 대상:

- `OPENAI_API_KEY`
- `GEMINI_API_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- JWT / provider key 형태의 직접 패턴

보안 DoD는 현재 저장소 기준으로 충족된다.

## 7. 결론

2026-03-09 기준 `#21`의 남은 DoD 3개는 모두 충족된다.

- `보안 점검` DoD: PASS
- `빌드/배포/회귀` DoD: PASS
- `SQL vs 앱 통계` DoD: PASS

즉, `#21`은 이제 닫을 수 있다. `#595`는 해결 완료 blocker로 정리한다.
