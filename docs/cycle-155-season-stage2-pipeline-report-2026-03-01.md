# Cycle 155 Report — Season Stage2 Aggregation Pipeline (2026-03-01)

## 1. Scope
- Issue: #125
- Goal: 시즌 집계 스키마 + 감쇠/정산 배치 파이프라인 + 보상 발급 기록 + 멱등 처리 구현
- Branch: `codex/season-stage2-pipeline-125`

## 2. Implemented
- Added migration:
  - `supabase/migrations/20260301090000_season_stage2_batch_pipeline.sql`
- Added docs:
  - `docs/season-stage2-pipeline-v1.md`
  - `docs/supabase-schema-v1.md` Stage2 section update
  - `docs/supabase-migration.md` Stage2 QA SQL update
  - `README.md` document index update
- Added checks:
  - `scripts/season_stage2_pipeline_unit_check.swift`
  - `scripts/ios_pr_check.sh` includes new unit check
- Runtime hook:
  - `supabase/functions/sync-walk/index.ts` points stage now calls `rpc_ingest_season_tile_events`

## 3. Acceptance Mapping
1. 시즌 테이블 설계
- `season_runs`, `season_user_scores`, `season_tile_scores`, `season_rewards` 생성 완료

2. 타일 이벤트 적재 및 중복 방지
- `tile_events` 생성
- `(season_id, owner_user_id, tile_id, event_day)` unique 제약으로 멱등 처리
- generated `idempotency_key` 제공

3. 감쇠/정산 배치
- `rpc_apply_season_daily_decay` 구현
- `rpc_finalize_season` 구현

4. 정산 스냅샷/보상 기록
- `season_user_scores` 스냅샷 집계 유지
- `season_rewards` 발급 이력 저장

5. 실패 재시도/멱등
- ingest/upsert, finalize(do nothing on conflict)로 재실행 안전성 확보

## 4. Validation
- `swift scripts/season_stage2_pipeline_unit_check.swift` -> PASS
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> PASS

## 5. Follow-ups
- 운영 스케줄러에서 `rpc_apply_season_daily_decay` / `rpc_finalize_season` 주기 호출 연결
- Home UI Stage3(#126)에서 `rpc_get_season_leaderboard` 연동
