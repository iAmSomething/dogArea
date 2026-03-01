# Cycle 156 Report — Season Stage3 UI Integration (2026-03-01)

- Issue: `#126 [Task][Season][Stage 3] 시즌 진행/결과/보상 UI 통합`
- Branch: `codex/issue-126-season-stage3-ui-integration`

## 요약
- Home/Map/Profile 경로에 시즌 진행/결과/보상 UI를 통합했다.
- 시즌 카드는 `접기/펼치기`, `남은 시간`, `지난 결과 재확인`, `시즌 상세 시트`를 제공한다.
- 시즌 종료 결과 모달에서 보상 상태를 노출하고 실패/대기 상태의 재수령 버튼을 제공한다.
- 지도 heatmap은 4단계 시즌 타일 강도와 점령/유지 상태 요약/범례를 제공한다.
- 프로필 이미지는 시즌 티어 기반 프레임/배지를 표시한다.

## 변경 파일
- `dogArea/Views/HomeView/HomeView.swift`
- `dogArea/Views/HomeView/HomeViewModel.swift`
- `dogArea/Views/MapView/MapViewModel.swift`
- `dogArea/Views/MapView/MapView.swift`
- `dogArea/Views/MapView/MapSubViews/MapSettingView.swift`
- `dogArea/Views/ProfileSettingView/NotificationCenterView.swift`
- `docs/season-stage3-ui-integration-v1.md`
- `scripts/season_stage3_ui_unit_check.swift`
- `scripts/ios_pr_check.sh`

## 테스트
- `swift scripts/season_stage3_ui_unit_check.swift` -> PASS
- `bash scripts/ios_pr_check.sh` -> PASS (iOS/watch build 포함)

## 리스크/후속
- 시즌 보상 수령은 현재 로컬 상태 전이 기반이며, 서버 발급 영수증 연동은 후속으로 확장 필요.
- 시즌 상세 시트의 점수 항목은 현행 로컬 모델 기준이며, Stage2 서버 상세 breakdown API 연동 시 정밀화 필요.
