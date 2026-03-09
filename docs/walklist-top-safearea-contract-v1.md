# WalkList Top Safe Area Contract v1

## 목적
- 산책 기록 탭의 상단 타이틀, 허브 카드, sticky section header가 status bar와 겹치지 않도록 재발 방지 계약을 고정한다.
- `#622`에서 드러난 문제를 화면별 임시 top padding이 아니라 공통 scaffold 계약과 산책 기록 화면 책임으로 분리한다.

## 원인 정리
- 산책 기록 탭은 `ScrollView + LazyVStack(... pinnedViews: [.sectionHeaders])` 구조를 사용한다.
- 이 구조에서 루트 상단 예약을 `safeAreaPadding(.top)`에만 의존하면, sticky section header가 상단에 pin 될 때 status bar와 충돌할 수 있다.
- 따라서 루트 상단 예약은 `safeAreaInset(edge: .top)`이 맡고, 산책 기록 화면은 `contentTopPadding` 수준의 내부 리듬만 책임져야 한다.

## 계약
- 루트 상단 예약은 `AppTabScaffold.appTabRootScrollLayout`의 `safeAreaInset(edge: .top)`이 담당한다.
- 산책 기록 화면은 `.appTabRootScrollLayout(extraBottomPadding: AppTabLayoutMetrics.comfortableScrollExtraBottomPadding)`을 사용한다.
- 산책 기록 화면 내부의 추가 상단 간격은 `WalkListRootLayoutMetrics.contentTopPadding` 한 곳에서만 조정한다.
- `WalkListSectionHeaderView`는 sticky pin 상태에서도 같은 top safe area 예약 안에서 머물러야 한다.
- 섹션 헤더 배경은 `Color.appTabScaffoldBackground`를 유지해 status bar 아래 카드/셀과 시각적으로 겹쳐 보이지 않게 한다.

## 책임 분리
- `AppTabScaffold`
  - non-map 루트 상단 예약 공간을 제공한다.
  - pinned section header까지 포함한 루트 safe area 계약을 담당한다.
- `WalkListView`
  - 허브와 섹션 사이의 내부 리듬을 조정한다.
  - 루트 top inset override나 임시 큰 패딩으로 문제를 덮지 않는다.
- `WalkListSectionHeaderView`
  - sticky 상태에서도 읽기 쉬운 배경/간격/접근성 식별자를 유지한다.

## 금지 사항
- `WalkListView`에 임시 대형 `.padding(.top, ...)`을 다시 추가하는 것
- sticky section header 충돌을 섹션 헤더 자체 top padding으로만 숨기는 것
- `appTabRootScrollLayout`의 top reservation을 화면별 override로 되돌리는 것

## QA 체크
1. `iPhone mini/기본/Pro Max` 계열에서 산책 기록 첫 진입 시 `walklist.header.title`, 기본 행동 카드, 캘린더 카드가 status bar 아래에 있는지 확인한다.
2. `UICTContentSizeCategoryAccessibilityXL` 이상에서 헤더 타이틀/부제가 줄바꿈돼도 status bar와 겹치지 않는지 확인한다.
3. 스크롤을 내려 `walklist.section.thisWeek`가 sticky 상태가 되었을 때 `minY >= 52`를 유지하는지 확인한다.
4. 산책 상세 진입 후 뒤로 돌아와도 다시 sticky header와 상단 허브가 같은 safe area 계약을 유지하는지 확인한다.

## 회귀 검증
- 정적 체크: `swift scripts/walklist_top_safearea_contract_unit_check.swift`
- 기능 회귀: `FeatureRegressionUITests/testFeatureRegression_WalkListStickySectionHeaderStaysBelowStatusBar`
- 기능 회귀: `FeatureRegressionUITests/testFeatureRegression_NonMapTabRootHeadersStayBelowStatusBar`
- 매트릭스: `FR-WALK-002C` in `docs/ui-regression-matrix-v1.md`
