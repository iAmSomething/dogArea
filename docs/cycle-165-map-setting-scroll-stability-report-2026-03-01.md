# Cycle 165 - Map 설정 시트 스크롤 안정화 보강 (2026-03-01)

## 이슈
- #194 `[Bug][Map] 지도 설정 시트 스크롤 불가/내용 잘림`

## 작업 요약
- `MapSettingView` ScrollView 하단 안전 여백 추가로 하단 잘림 체감 완화
- 스크롤 인디케이터 노출로 스크롤 가능성 인지성 강화

## 변경 파일
- `dogArea/Views/MapView/MapSubViews/MapSettingView.swift`

## 상세 변경
1. ScrollView content에 하단 안전 패딩 추가
- `.safeAreaPadding(.bottom, 18)`

2. 스크롤 인디케이터 노출
- `.scrollIndicators(.visible)`

## 테스트
1. 빌드
- `xcodebuild ... build` 성공 (경고만 존재)

2. 체크 스크립트
- `DOGAREA_SKIP_BUILD=1 ./scripts/ios_pr_check.sh` 통과

## 결과
- 지도 설정 시트에서 하단 항목 접근성이 개선되었고,
- 작은 화면에서 스크롤 가능성 인지가 쉬워짐.
