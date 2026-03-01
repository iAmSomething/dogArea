# Cycle 159-160 - 비교군 오름차순 정렬 + 캐리커처 탭 제거/프로필 통합 (2026-03-01)

## 이슈
- #187 `[Task][Area] 비교군/다음목표 오름차순 정렬 일관화`
- #186 `[Task][IA] 캐리커처 전용 탭 제거 + 프로필 편집 플로우 통합`

## 문서 선작성
- `docs/area-goal-ascending-order-v1.md`
- `docs/profile-caricature-flow-v2.md`

## 구현 요약
1. 비교군 오름차순 일관화
- `AreaMeterCollection`의 커스텀/폴백 데이터를 `area asc`로 통일.
- 오름차순 기준에 맞게 인접 목표 계산 함수 보정:
  - `nearistArea(of:)` -> `last(where: < myArea)`
  - `closeArea(of:)` -> `first(where: > myArea)`
- `HomeViewModel`에서:
  - `featuredGoalAreas` 정렬을 오름차순으로 변경
  - `findIndex`/`updateCurrentMeter` 오름차순 기준으로 보정
  - `nearlistMore`에서 featured 후보와 일반 후보를 비교해 더 작은(가까운) 다음 목표를 선택

2. 캐리커처 전용 탭 제거 + 프로필 편집 통합
- 하단 탭 IA를 `홈/산책 목록/지도/설정` 4탭으로 변경.
- `RootView`에서 이미지 탭 분기 제거.
- `ProfileFieldEditSheet`에 "캐리커처 생성/재생성" 섹션 추가.
- `SettingViewModel`에 `regenerateSelectedPetCaricature()` 추가:
  - feature flag/회원 권한 검증
  - 선택 반려견 이미지 유효성 검증
  - processing/ready/failed 상태 반영
  - 성공/실패 메시지 및 메트릭 기록

## 변경 파일
- `dogArea/Views/HomeView/AreaMeters.swift`
- `dogArea/Views/HomeView/HomeViewModel.swift`
- `dogArea/Views/GlobalViews/BaseView/CustomTabBar.swift`
- `dogArea/Views/GlobalViews/BaseView/RootView.swift`
- `dogArea/Views/ProfileSettingView/SettingViewModel.swift`
- `dogArea/Views/ProfileSettingView/NotificationCenterView.swift`

## 검증
- `swift scripts/area_reference_db_ui_unit_check.swift` PASS
- `swift scripts/project_stability_unit_check.swift` PASS
- `bash scripts/ios_pr_check.sh` PASS
  - 문서/정적 유닛 체크 통과
  - iOS build 성공
  - watchOS build 성공

## 후속 메모
- `TextToImageView` 파일은 현재 탭 진입점만 제거된 상태이며, 필요 시 파일/뷰모델 정리 사이클에서 제거 가능.
