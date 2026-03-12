# WalkList Top Safe Area Contract v1

## 목적
- 산책 기록 탭의 루트 타이틀 chrome과 sticky section header가 status bar 및 고정 top chrome과 겹치지 않도록 재발 방지 계약을 고정한다.
- `#622`에서 드러난 문제를 화면별 임시 top padding이 아니라 공통 scaffold 계약과 산책 기록 화면 책임으로 분리한다.

## 원인 정리
- 산책 기록 탭은 `ScrollView + LazyVStack(... pinnedViews: [.sectionHeaders])` 구조를 사용한다.
- 이 구조에서 루트 타이틀을 `safeAreaInset(edge: .top)` 기반 chrome으로만 고정하면, sticky section header는 여전히 scroll view 자체의 상단에 pin 된다.
- 따라서 산책 기록 화면은 루트 타이틀 chrome과 스크롤 본문을 서로 다른 레이아웃 영역으로 분리하는 `nonMapRootPinnedHeaderLayout`을 사용해야 한다.
- 요약 카드, 컨텍스트 카드, 월간 캘린더는 scroll content 안에 남겨 sticky section header와 같은 스크롤 문맥을 유지한다.

## 계약
- 루트 상단 예약 자체는 `AppTabScaffold.appTabRootScrollLayout`의 `safeAreaInset(edge: .top)` 계약을 공유한다.
- 산책 기록 화면은 `.appTabRootScrollLayout(extraBottomPadding: AppTabLayoutMetrics.defaultScrollExtraBottomPadding, topSafeAreaPadding: 0)`을 사용한다.
- 산책 기록의 루트 타이틀 블록은 `nonMapRootPinnedHeaderLayout()`으로 scroll content 밖 상단에 고정한다.
- `WalkListDashboardHeaderView`가 렌더링하는 요약/컨텍스트/캘린더 카드는 scroll content 안에 위치해야 한다.
- `WalkListSectionHeaderView`는 sticky pin 상태에서도 `walklist.header.section` 루트 chrome 바로 아래에 머물러야 한다.
- 대표 sticky QA 대상 식별자는 `walklist.section.thisWeek`다.
- 섹션 헤더 배경은 `Color.appTabScaffoldBackground`를 유지해 status bar 아래 카드/셀과 시각적으로 겹쳐 보이지 않게 한다.

## 책임 분리
- `AppTabScaffold`
  - non-map 루트 상단 예약 공간을 제공한다.
  - pinned section header 화면은 `nonMapRootPinnedHeaderLayout`, 일반 루트 화면은 `nonMapRootTopChrome`으로 분기한다.
- `WalkListView`
  - 루트 타이틀만 `nonMapRootPinnedHeaderLayout`으로 고정해 scroll content 밖으로 분리한다.
  - 대시보드 카드 묶음은 scroll content 안에 유지한다.
  - 루트 top inset override나 임시 큰 패딩으로 문제를 덮지 않는다.
- `WalkListSectionHeaderView`
  - sticky 상태에서도 읽기 쉬운 배경/간격/접근성 식별자를 유지한다.

## 금지 사항
- `WalkListView`에 임시 대형 `.padding(.top, ...)`을 다시 추가하는 것
- sticky section header 충돌을 섹션 헤더 자체 top padding으로만 숨기는 것
- `appTabRootScrollLayout`의 top reservation을 화면별 override로 되돌리는 것

## QA 체크
1. `iPhone mini/기본/Pro Max` 계열에서 산책 기록 첫 진입 시 `walklist.header.title`이 status bar 아래에 있고, 첫 요약 카드가 그 아래 scroll content에 배치되는지 확인한다.
2. 스크롤해도 `walklist.header.title` / `walklist.header.subtitle` 루트 타이틀 chrome이 본문과 함께 올라가지 않는지 확인한다.
3. `UICTContentSizeCategoryAccessibilityXL` 이상에서 헤더 타이틀/부제가 줄바꿈돼도 status bar와 겹치지 않는지 확인한다.
4. 스크롤을 내려 섹션 헤더가 sticky 상태가 되었을 때 `walklist.header.section` 루트 chrome 바로 아래에 머무는지 확인한다.
5. 산책 상세 진입 후 뒤로 돌아와도 다시 sticky header와 루트 타이틀 chrome이 같은 safe area 계약을 유지하는지 확인한다.

## 회귀 검증
- 정적 체크: `swift scripts/walklist_top_safearea_contract_unit_check.swift`
- 기능 회귀: `FeatureRegressionUITests/testFeatureRegression_WalkListStickySectionHeaderStaysBelowStatusBar`
- 기능 회귀: `FeatureRegressionUITests/testFeatureRegression_NonMapTabRootHeadersStayBelowStatusBar`
- 매트릭스: `FR-WALK-002C` in `docs/ui-regression-matrix-v1.md`
