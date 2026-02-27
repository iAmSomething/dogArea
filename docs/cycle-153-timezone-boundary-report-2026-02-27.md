# Cycle 153 Report — Midnight/Timezone Boundary Aggregation (2026-02-27)

## 1. 대상
- Issue: `#153 [P0][Task] 자정/타임존 경계 세션 집계 정합 처리`
- Branch: `codex/cycle-153-timezone-boundary`

## 2. 구현 요약
- 홈 통계 집계를 세션 구간 overlap 기반으로 전환해 자정/주간 경계 분할 정확도 보강
- 홈 달력 날짜 표시를 세션 시작일 단일 표시에서 "걸친 모든 날짜 표시"로 확장
- 타임존/일자 경계 변경 notification 감지 후 홈 집계 자동 재계산
- 경계 세션의 전날/오늘 기여를 홈 카드로 명시

## 3. 변경 파일
- `dogArea/Views/HomeView/HomeViewModel.swift`
  - 구간 분할 계산기(`weightedAreaContribution`, `sessionOverlaps`) 추가
  - 타임존/일자 경계 감지 및 재집계 처리 추가
  - `DayBoundarySplitContribution` DTO 추가
- `dogArea/Views/HomeView/HomeView.swift`
  - 타임존 재집계 안내 문구 추가
  - 전날/오늘 분할 기여 카드 추가
- `dogArea/Source/TimeCheckable.swift`
  - thisWeek 필터를 [startOfWeek, endOfWeek) 범위로 보정
- `docs/session-boundary-aggregation-v1.md`
  - 경계 분할 규칙 문서화
- `scripts/timezone_boundary_aggregation_unit_check.swift`
  - 정적 회귀 체크 추가

## 4. 유닛 체크
- `swift scripts/timezone_boundary_aggregation_unit_check.swift` -> PASS
- `swift scripts/home_goal_tracker_ui_unit_check.swift` -> PASS
- `swift scripts/multi_dog_context_sync_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS

## 5. 리스크/후속
- 면적/시간 분배는 세션 전체에 균등 분포를 가정하므로, 포인트 시계열 기반 정밀 분배는 후속 고도화 과제.
- Season/Quest 엔진 본체가 활성화되면 동일 분할 유틸을 공용 계층으로 승격 필요.
