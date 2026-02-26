# Cycle #67 결과 보고서 (2026-02-26)

## 1. 이슈 확인
- 대상 이슈: `#67 [Task][UI] 홈 영역 비교 UI 재설계(Picker 제거 + 목표 카드화)`

## 2. 개발/문서 반영
- `docs/home-goal-tracker-ui-v1.md` 추가
  - 비활성 Picker 제거, 목표 카드(현재/다음/남은 면적) 정책 정리
  - Dynamic Type/줄바꿈/접근성 라벨 기준 명시
  - 스크린샷 증적 정책(SE/Pro Max) 명시
- `docs/release-regression-checklist-v1.md` 갱신
  - 홈 목표 카드/접근성/스크린샷 체크 항목 추가
- `dogArea/Views/HomeView/HomeView.swift` 갱신
  - 비활성 inline Picker 제거
  - `goalTrackerCard` 기반 목표 카드 UI 적용
  - 비교군 `더보기` CTA를 `AreaDetailView`로 일원화
  - 카드 접근성 라벨 추가
- `dogArea/Views/HomeView/HomeViewModel.swift` 갱신
  - `nextGoalArea`, `remainingAreaToGoal`, `goalProgressRatio` 계산 프로퍼티 추가
- `scripts/home_goal_tracker_ui_unit_check.swift` 추가
  - Picker 제거/목표 카드/접근성/스크린샷 체크리스트 반영 검증

## 3. 유닛 테스트
- `swift scripts/home_goal_tracker_ui_unit_check.swift` -> `PASS`
- `swift scripts/release_regression_checklist_unit_check.swift` -> `PASS`
- `swift scripts/viewmodel_modernization_unit_check.swift` -> `PASS`

## 4. 비고
- 비교군 데이터 자체 확장 없이 UI 계층만 재구성했으며, 비교군 상세 리스트는 기존 `AreaDetailView` 경로를 유지했다.
