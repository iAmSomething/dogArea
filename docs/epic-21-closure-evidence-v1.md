# Epic #21 Closure Evidence Snapshot (2026-03-09)

- 대상 에픽: #21 `[Epic] 2026 안정화/고도화: Supabase 전환 + 다견 + watchOS + 캐리커처`
- 근거 수집 이슈: #412 `[Epic/QA] #21 종료를 위한 운영 검증·보안 근거 수집`
- 잔여 blocker 이슈: #595 `[Epic/QA] #21 closure blocker: linked migration rollout 재개 및 stats evidence 재수집`

## 1. 목적

`#21`의 남은 DoD 3개를 2026-03-09 기준으로 재점검하고, 바로 닫을 수 있는 항목과 아직 남겨야 하는 blocker를 분리한다.

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
| 하위 이슈 DoD 완료 + main 병합 기준 빌드/배포/회귀 통과 | `BLOCKED` | `bash scripts/backend_pr_check.sh` PASS, `bash scripts/ios_pr_check.sh` PASS, `npx --yes supabase migration list --linked`에서 마지막 migration 1건 drift 확인 | linked DB에 `20260309043000_realtime_retention_cleanup_rollout.sql` 미적용 상태가 남아 있어 `배포 통과`를 아직 체크할 수 없다. |
| Supabase 운영 검증 SQL 결과와 앱 통계(산책수/시간/면적) 합치 | `BLOCKED` | `sync-walk action=get_backfill_summary`와 `view_owner_walk_stats` 비교 결과 `session_count / point_count / total_area_m2`는 일치 | SQL 뷰 `public.view_owner_walk_stats`에 `total_duration_sec`가 없어 시간까지 포함한 완전 일치 증거를 남길 수 없다. |
| 서비스 롤 키/모델 API 키 앱 노출 0건 | `PASS` | `swift scripts/security_key_exposure_unit_check.swift` PASS | 저장소 기준 하드코딩 시크릿 노출 0건 확인. |

## 4. linked Supabase 배포 상태

### 4.1 migration list 결과

`npx --yes supabase migration list --linked` 재실행 결과:

- `20260307154000_widget_summary_envelope_compat_rollout.sql` 적용됨
- `20260307193000_backend_edge_failure_dashboard_view.sql` 적용됨
- `20260308103000_weather_canonical_server_state.sql` 적용됨
- `20260309043000_realtime_retention_cleanup_rollout.sql` 미적용

즉, linked DB drift는 마지막 migration 1건만 남은 상태다.

### 4.2 db push 재시도 결과

`npx --yes supabase db push --linked` 실행 결과:

- 위 3개 migration은 원격에 반영됨
- 마지막 migration `20260309043000_realtime_retention_cleanup_rollout.sql`에서 실패
- 실패 코드: `SQLSTATE 42803`
- 실패 지점: `public.view_realtime_retention_delete_debt`
- 원인 요약: `boundaries.now_ts`가 `GROUP BY` 또는 aggregate 없이 view select에 포함됨

따라서 `#21` DoD의 `배포 통과`는 아직 충족되지 않는다. 이 blocker는 `#595`로 분리했다.

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

판정:

- `session_count / point_count / total_area_m2`는 SQL 뷰와 app-facing summary가 일치
- 하지만 `view_owner_walk_stats`에는 `total_duration_sec` 컬럼이 존재하지 않음
- 따라서 `산책수/시간/면적` 전부를 포함한 DoD는 아직 닫을 수 없음

### 5.3 남은 작업

`#595`에서 아래를 마무리해야 한다.

1. `20260309043000_realtime_retention_cleanup_rollout.sql` 수정 및 linked 적용
2. `view_owner_walk_stats` 또는 동등 SQL surface에 `total_duration_sec` 근거 추가
3. 같은 방식으로 `get_backfill_summary`와 SQL 결과를 다시 비교해 `시간`까지 포함한 완전 일치 증적 확보

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

2026-03-09 기준 `#21`은 아직 닫지 않는다.

- `보안 점검` DoD는 `PASS`
- `빌드/회귀`는 현재 `main` 기준 체크가 통과했지만, linked migration drift가 남아 있어 `배포 통과`로 닫을 수 없음
- `SQL vs 앱 통계`는 `건수/포인트/면적`은 맞지만 `시간(total_duration_sec)` 근거가 빠져 있어 완결 아님

즉, 현재 상태는 **에픽 종료 직전 단계**이며, blocker는 `#595` 하나로 수렴된다.
