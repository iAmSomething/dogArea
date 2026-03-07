# Territory Widget Next Goal Summary v1

## 목표

- 중형 Territory 위젯에서 기존 타일 지표(`오늘 / 주간 / 방어 예정`)와 함께 `다음 목표 / 남은 면적 / 진행률`을 보여준다.
- 홈/상세 화면의 목표 계산 공식은 그대로 유지한다.
- 선택 반려견 컨텍스트가 있으면 그 문맥을 그대로 유지한다.
- guest / empty / offline / sync-delayed 상태에서 실제 목표가 확정되지 않았는데 확정된 것처럼 보이지 않게 한다.

## 데이터 책임 분리

### 서버 RPC가 계속 담당하는 값

- `today_tile_count`
- `weekly_tile_count`
- `defense_scheduled_tile_count`
- `score_updated_at`
- `refreshed_at`
- `has_data`

위 값은 기존 `rpc_get_widget_territory_summary` 경로를 그대로 사용한다.

### 앱 로컬이 새로 담당하는 값

- `contextLabel`
- `nextGoalName`
- `nextGoalAreaM2`
- `remainingAreaM2`
- `progressRatio`
- `goalContext.message`

이 값은 `TerritoryWidgetGoalContextService`가 로컬 polygon + 선택 반려견 + area reference snapshot으로 계산한다.

## 선택 반려견 컨텍스트 규칙

- `contextKey = userId|selectedPetId` 형식으로 Territory widget snapshot에 저장한다.
- 컨텍스트가 바뀌면 TTL과 상관없이 위젯 sync를 다시 수행한다.
- offline cached fallback은 `current.contextKey == requestedContextKey`일 때만 허용한다.
- 즉, 다른 반려견으로 전환된 뒤 예전 반려견 목표가 위젯에 남아 보이면 안 된다.

## 상태별 표시 규칙

| 상태 | 목표 블록 | 규칙 |
| --- | --- | --- |
| `memberReady + goal ready` | 다음 목표명 + 남은 면적 + 진행률 | 정상 표시 |
| `memberReady + goal completed` | 완료 메시지 + 100% | 준비된 비교 구역을 모두 달성한 상태 |
| `emptyData` | 목표 준비 중 메시지 | 첫 산책 전에는 목표 확정처럼 보이지 않음 |
| `offlineCached` | 마지막 성공 goal context 재사용 | 동일 `contextKey`일 때만 허용 |
| `syncDelayed` | 동기화 필요 메시지 | 캐시가 없거나 stale이면 목표 확정 금지 |
| `guestLocked` | 로그인 유도 | 목표 지표 노출 안 함 |

## 중형 위젯 레이아웃

1. 상단: 상태 배지 + 업데이트 시각
2. 제목: `영역 현황`
3. 보조 라벨: `선택 반려견 · {name}` 또는 `현재 기록 기준`
4. 목표 요약 카드:
   - 제목: `다음 목표`
   - 본문: 목표명 / 남은 면적 / 목표 면적
   - 우측: 진행률 퍼센트
   - 하단: 상태 설명 문구
5. 하단: `오늘 / 주간 / 방어 예정` 타일 3개

## 계산 정책

- 목표 계산은 `HomeAreaAggregationService.nextReferenceArea(...)`와 동일 규칙을 사용한다.
- 비교 구역 기준은 `AreaReferenceSnapshot.featuredAreas` 우선, 없으면 기본 정렬 비교군을 사용한다.
- `remainingArea = max(0, nextGoal.area - currentArea.area)`
- `progressRatio = clamp(currentArea.area / nextGoal.area, 0...1)`

## 검증 기준

- Territory 위젯 snapshot에 `goalContext`와 `contextKey`가 저장된다.
- `selectedPet` 변경 후 강제 sync 시 이전 반려견 context cache를 재사용하지 않는다.
- `territory_status_widget_unit_check.swift`
- `territory_widget_next_goal_summary_unit_check.swift`
- `ios_pr_check.sh`
