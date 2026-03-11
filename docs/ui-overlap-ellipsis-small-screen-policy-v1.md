# UI Overlap / Ellipsis / Small Screen Policy v1

## 목적
- 서로 다른 UI surface가 겹쳐 보이지 않게 한다.
- 사용자 노출 텍스트가 `...`로 잘린 채 남지 않게 한다.
- 작은 화면과 큰 글자 크기에서 먼저 성립하는 레이아웃을 기본값으로 삼는다.

## 공통 규칙
1. 겹침 금지
   - 카드, 버튼, 배너, 탭바, sticky header는 서로 다른 surface로 읽혀야 한다.
   - `padding`과 `zIndex` 숫자 보정만으로 겹침을 숨기지 않는다.
2. `...` 금지
   - 주요 값, 제목, 상태 문구, 반려견 이름이 `...`로 남으면 실패다.
   - 한 줄에 다 못 담으면 줄 수를 늘리거나, 카피를 축약하거나, 별도 상세 surface로 분리한다.
3. 작은 화면 우선
   - 최소 지원 화면 + Dynamic Type 확대 조합에서 먼저 검증한다.
   - preview만으로 끝내지 않고 UI 회귀 테스트나 캡처 증적으로 확인한다.

## 이번 적용 범위
- `WalkListCell`
- `WalkListMetricTileView`
- `WalkListPrimaryLoopSummaryCardView`
- `WalkListContextSummaryCardView`

## 적용 원칙
- 산책 기록 셀은 날짜/시간 -> 대표 값 -> 반려견 문맥 -> 메트릭 타일 -> 썸네일 순으로 읽힌다.
- 메트릭 타일은 `minHeight 64pt` compact budget을 유지하되, 긴 값은 최대 3줄까지 허용한다.
- 상단 허브의 보조 문구는 1줄 강제가 아니라 2줄까지 허용해 `...` 대신 줄바꿈으로 처리한다.
- 긴 반려견 이름과 큰 면적 값은 small-screen preview에서 같은 높이 리듬으로 유지돼야 한다.

## 회귀 기준
- `FeatureRegressionUITests/testFeatureRegression_WalkListLongMetricTilesStayUniformOnSmallScreen`
- `FeatureRegressionUITests/testFeatureRegression_WalkListStickySectionHeaderStaysBelowStatusBar`
- `FeatureRegressionUITests/testFeatureRegression_WalkListMetricTilesStayCompactWithoutVerboseCopy`
