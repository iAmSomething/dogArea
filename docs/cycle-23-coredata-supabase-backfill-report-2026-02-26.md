# Cycle #23 결과 보고서 (2026-02-26)

## 1. 이슈 확인
- 대상 이슈: `#23 [Task] CoreData -> Supabase 이중쓰기 및 백필 구현`
- 상태: 구현/유닛체크 완료, PR 생성 예정

## 2. 문서화 선반영
- 신규 계약 문서: `docs/coredata-supabase-backfill.md`
  - DTO 규격(`WalkSessionBackfillDTO`, `WalkPointBackfillDTO`)
  - stage payload(`session/points/meta`)
  - 검증 리포트 허용 오차
  - 재시도/운영 기준
- 전환 문서 링크 반영: `docs/data-layer-transition-v1.md`

## 3. 개발 완료 항목
1. CoreData DTO 변환기
- `CoreDataSupabaseBackfillDTOConverter` 추가
- `Polygon/PolygonEntity -> WalkSessionBackfillDTO` 변환 구현

2. `walk_sessions` 업서트 + `walk_points` 배치 insert 경로
- 앱 outbox payload를 `points_json` 포함 형태로 확장
- 신규 Edge Function `supabase/functions/sync-walk/index.ts` 추가
  - `sync_walk_stage`: stage별 저장
  - `get_backfill_summary`: 원격 합계 조회
  - `walk_points` upsert on conflict `(walk_session_id, seq_no)`

3. retry 큐/재시도 경로
- 기존 `SyncOutboxStore` 재시도 로직 유지
- payload만 확장하여 기존 flush/retry 흐름과 결합

4. 백필 전후 합계 검증 리포트
- `GuestDataUpgradeReport`에 원격 합계/검증 결과 필드 추가
- 로컬-원격 비교 후 `validationPassed`, `validationMessage` 저장
- Home/Root 배너에 검증 상태 노출

## 4. 유닛 테스트
- `swift scripts/coredata_supabase_backfill_unit_check.swift` -> PASS
- `swift scripts/walk_sync_consistency_outbox_unit_check.swift` -> PASS
- `swift scripts/guest_data_upgrade_unit_check.swift` -> PASS

## 5. 제한/메모
- 이 워크트리 환경에는 `deno`가 없어 Edge Function 타입체크(`deno check`)는 미실행.
- 원격 Supabase E2E QA(실데이터 검증)는 인증/환경변수 세션 기준으로 별도 실행 필요.

## 6. 수용 기준 대응
- [x] 세션/포인트/면적/시간 합계 검증 리포트 로직 추가
- [x] 멱등 재실행 시 중복 증가 방지(`walk_sessions` PK, `walk_points` unique upsert)
- [x] 실패 건 재시도 경로 유지 및 리포트 반영
