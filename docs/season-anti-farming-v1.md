# Season Anti-Farming Rule v1

## 1. 목적
시즌 점수에서 동일 타일 반복 파밍을 억제하고, 실제 이동/신규 경로 중심의 기여를 우대한다.

연결 이슈:
- 구현: #146
- 상위 Epic: #123

## 2. 핵심 규칙
- 동일 타일 반복 억제:
  - 동일 타일(`tile_decimal_precision`) 재입력이 `30분` 이내면 해당 이벤트 점수 `0점`
- 신규 경로 보너스:
  - 세션 `novelty_ratio = unique_tiles / total_points`
  - 보너스 = `base_tile_score * new_route_bonus_weight * novelty_ratio`
  - 최초 타일 기여(`is_first_tile_hit=true`)에만 부여
- 비정상 반복 차단:
  - `repeat_suppressed_count >= suspicious_repeat_threshold`
  - `novelty_ratio <= suspicious_max_novelty_ratio`
  - `session_distance_m <= suspicious_low_movement_meters`
  - 모두 충족 시 `score_blocked=true` (정책 활성 시 총점 0)

## 3. 서버 파라미터
테이블: `season_scoring_policies`
- `repeat_cooldown_minutes`
- `tile_decimal_precision`
- `base_tile_score`
- `new_route_bonus_weight`
- `suspicious_repeat_threshold`
- `suspicious_max_novelty_ratio`
- `suspicious_low_movement_meters`
- `suspicious_block_enabled`

## 4. 이벤트/감사 로그
- 이벤트 원장: `season_tile_score_events`
  - per-point 점수 계산 결과(`base_score`, `novelty_bonus`, `final_score`, `suppression_reason`)
- 감사 로그: `season_score_audit_logs`
  - severity: `info|warn|block`
  - 차단 여부(`blocked`) + 판정 근거 payload 저장
- 운영 뷰: `view_season_score_audit_24h`

## 5. RPC 계약
함수: `rpc_score_walk_session_anti_farming(target_walk_session_id, now_ts)`

반환 필드:
- `total_points`, `unique_tiles`, `novelty_ratio`
- `repeat_suppressed_count`, `suspicious_repeat_count`
- `base_score`, `new_route_bonus`, `total_score`
- `score_blocked`
- `explain`(UI 표시용 이유/정책 스냅샷)

## 6. UX 연결 계약
`sync-walk` points stage 응답에 `season_score_summary`를 포함한다.

예시:
```json
{
  "ok": true,
  "stage": "points",
  "walk_session_id": "...",
  "point_count": 120,
  "season_score_summary": {
    "total_score": 42.8,
    "score_blocked": false,
    "repeat_suppressed_count": 14,
    "explain": {
      "ui_reason": "동일 타일 반복 입력(30분 이내)은 점수에서 제외되었습니다."
    }
  }
}
```

## 7. 검증 체크리스트
- [ ] 동일 타일 10회 반복에서 30분 내 반복 이벤트 점수가 0으로 계산
- [ ] 신규 경로 비율이 높은 세션이 더 높은 보너스를 획득
- [ ] 비정상 반복 패턴에서 `score_blocked=true` + 감사 로그 적재
- [ ] 정상 산책(충분 이동/신규경로)에서 과도 차감 없이 점수 반영
