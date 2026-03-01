# Season Stage 2 Aggregation Pipeline v1

## 1. 목적
시즌 정책 Stage 1(규칙 고정) 이후, 서버에서 일관되게 집계/감쇠/정산/보상 발급을 수행하기 위한 Stage 2 파이프라인을 확정한다.

연결 이슈:
- 구현: #125
- 정책: #124
- 상위 Epic: #123

## 2. 핵심 결정
- 점수 원본은 `tile_events` 일 단위 원장으로 저장한다.
- 멱등 키는 `(season_id, owner_user_id, tile_id, event_day)` 고정이다.
- 감쇠는 실시간 계산이 아니라 `일 배치 + 조회 반영` 혼합으로 처리한다.
- 정산 결과는 `season_rewards`에 불변(append-only) 기록한다.

## 3. 스키마
- `season_runs`
  - 시즌 주기/정책/정산 상태(`active|settling|settled`) 보관
- `tile_events`
  - 타일 점수 원장(일 단위)
  - unique: `(season_id, owner_user_id, tile_id, event_day)`
  - generated `idempotency_key` 제공
- `season_tile_scores`
  - 시즌-사용자-타일 누적 점수 + 감쇠 반영값
- `season_user_scores`
  - 리더보드용 사용자 집계 스냅샷(점수/랭크/티어)
- `season_rewards`
  - 시즌 종료 후 보상 발급 이력(멱등 발급)

## 4. RPC 계약
- `rpc_ingest_season_tile_events(target_walk_session_id, now_ts)`
  - `season_tile_score_events`를 기반으로 `tile_events` upsert
  - 사용자 타일/유저 점수 재계산 + 랭킹 갱신
- `rpc_apply_season_daily_decay(target_season_id, now_ts)`
  - 서비스 롤 전용 일 배치
  - `season_tile_scores` 감쇠 적용 + `season_user_scores` 재집계
- `rpc_finalize_season(target_season_id, now_ts)`
  - 서비스 롤 전용 정산
  - 정산 창(`week_end + settlement_delay_hours`) 이후 실행
  - `season_rewards` 발급 + 시즌 상태 `settled`
- `rpc_get_season_leaderboard(target_season_id, top_n)`
  - 익명화된 `user_key(md5)` 기반 리더보드 조회

## 5. 앱 연동 경로
- `supabase/functions/sync-walk` points stage에서 다음 순서로 호출:
1. `rpc_score_walk_session_anti_farming`
2. `rpc_ingest_season_tile_events`
3. `rpc_apply_weather_replacement`

응답 필드:
- `season_score_summary`
- `season_pipeline_summary`
- `weather_replacement_summary`

## 6. 운영 배치
- 감쇠 배치: 하루 1회 이상 `rpc_apply_season_daily_decay`
- 정산 배치: 시즌 종료 + 2시간 이후 `rpc_finalize_season`
- 모니터링 뷰: `view_season_batch_status_14d`

## 7. 검증 체크
1. 동일 세션 재전송 시 `tile_events` 행 수 증가 없음(멱등)
2. 감쇠 배치 재실행 시 `season_user_scores.total_score` 일관
3. 정산 재실행 시 `season_rewards` 중복 발급 없음
4. 리더보드 동점 정렬이 결정적(`total_score -> active_tile_count -> new_tile_capture_count -> last_contribution_at -> user_id`)
