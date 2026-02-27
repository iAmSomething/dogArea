# Season Weekly Policy Stage 1 v1

## 1. 목적
주간 시즌 점수/감쇠/정산/동점 규칙을 v1으로 고정해, 서버 구현(Stage 2)과 앱 UI(Stage 3)의 기준선을 일치시킨다.

연결 이슈:
- 정책 확정: #124
- 상위 Epic: #123

## 2. 시즌 캘린더/정산 윈도우
- 시즌 주기: 사용자 로컬 타임존 기준 `월요일 00:00` ~ `일요일 23:59:59`
- 정산 시작: 시즌 종료 후 `+2시간` (지연 업로드 흡수)
- 정산 잠금: 정산 스냅샷 확정 이후 수정 금지(다음 시즌 반영)

운영 파라미터:
- `season_settlement_delay_hours = 2`
- `season_timezone_mode = user_local`

## 3. 점수 산식(v1)
기본 이벤트 점수:
- 신규 타일 점령: `+5`
- 동일 타일 유지 방문(일 1회): `+1`
- 동일 타일 당일 2회 이상 유지 방문: `+0`

세션 점수:
- `session_score = sum(tile_event_score)`

주간 점수:
- `season_week_score = sum(session_score) - decay_penalty`

운영 파라미터:
- `new_tile_score = 5`
- `hold_tile_daily_score = 1`
- `hold_tile_daily_cap = 1`

## 4. 감쇠 규칙(v1)
- 마지막 방문 기준 `48시간` 경과 시 감쇠 시작
- 감쇠량: 타일 점수 하루 `-2`
- 하한: `0` 미만으로 내려가지 않음

식:
- `age_hours = now - last_visited_at`
- `decay_days = floor((age_hours - 48) / 24) + 1` (`age_hours > 48`일 때)
- `tile_effective_score = max(0, tile_raw_score - 2 * decay_days)`

운영 파라미터:
- `decay_grace_hours = 48`
- `decay_per_day = 2`
- `decay_floor = 0`

## 5. 동점 처리(v1)
동점 정렬 우선순위:
1. 활성 타일 수(`active_tile_count`) 내림차순
2. 신규 점령 수(`new_tile_capture_count`) 내림차순
3. 마지막 기여 시각(`last_contribution_at`) 오름차순(더 이른 기여 우선)
4. 사용자 ID 오름차순(완전 결정성 보장)

## 6. 티어/보상(v1)
티어:
- `Bronze`: 80점 이상
- `Silver`: 180점 이상
- `Gold`: 320점 이상
- `Platinum`: 520점 이상

보상:
- 티어 배지(시즌 배지)
- 프로필 프레임

주의:
- 시즌 중 티어 임계값 변경 금지
- 보상은 정산 스냅샷 기준 1회 발급

## 7. 예시 계산
### 7.1 신규 점령 10개
- 점수: `10 * 5 = 50`

### 7.2 3일 미방문 감쇠
- 타일 원점수: 12점
- 마지막 방문 후 72시간 경과
- 감쇠 시작 48시간 이후 1일 경과 -> `-2`
- 유효점수: `12 - 2 = 10`

### 7.3 시즌 종료 직전 업로드
- `일요일 23:58`에 산책 종료, 업로드는 `월요일 00:30`
- 정산 지연창(2시간) 내 업로드이므로 직전 시즌 반영
- `월요일 02:00` 이후 도착분은 다음 시즌 반영

## 8. 운영 파라미터 목록
- 점수: `new_tile_score`, `hold_tile_daily_score`, `hold_tile_daily_cap`
- 감쇠: `decay_grace_hours`, `decay_per_day`, `decay_floor`
- 정산: `season_settlement_delay_hours`, `season_timezone_mode`
- 랭크: `tier_threshold_bronze/silver/gold/platinum`
- 동점: `tiebreaker_order`

## 9. 검증 체크리스트
- [ ] 신규 타일 10개 케이스가 50점으로 일치
- [ ] 72시간 미방문 타일이 규칙대로 감쇠
- [ ] 정산 지연창 내 업로드 반영 여부 일치
- [ ] 동점 3중 비교 + 최종 결정키(user_id)로 순서가 고정
- [ ] 티어 컷(80/180/320/520) 경계값이 일관
