# TabBar Card Surface Viewport Density v1

## 목적
- `#728`, `#773` 요구사항대로 하단 탭바를 다시 `compact card surface`로 읽히게 만든다.
- `홈 / 산책 기록 / 라이벌 / 설정` 네 루트 화면의 상하 viewport density를 공통 scaffold 계약에서 함께 완화한다.
- gradient band를 지우되, 마지막 카드와 버튼이 탭바에 가려지지 않는 하단 안전 계약은 유지한다.

## 공통 수치 계약
- `AppTabLayoutMetrics.defaultTabBarReservedHeight = 110`
- `AppTabLayoutMetrics.nonMapRootTopSafeAreaPadding = 12`
- `AppTabLayoutMetrics.nonMapRootHeaderTopSpacing = 8`
- `AppTabLayoutMetrics.nonMapRootChromeBottomSpacing = 12`
- `AppTabLayoutMetrics.defaultScrollExtraBottomPadding = 12`

## 탭바 표면 계약
- `CustomTabBar`는 화면 하단 전체를 먹는 `LinearGradient` 밴드를 사용하지 않는다.
- 탭바는 좌우 inset이 있는 `RoundedRectangle` card surface를 사용한다.
- 지도 버튼 강조는 유지하되, center button lift를 줄여 전체 visual band를 compact하게 유지한다.
- selection emphasis는 전체 배경이 아니라 item별 capsule로 남긴다.

## 루트 화면 계약
- `홈 / 산책 기록 / 라이벌 / 설정`은 모두 `.appTabRootScrollLayout(extraBottomPadding: AppTabLayoutMetrics.defaultScrollExtraBottomPadding, topSafeAreaPadding: 0)`을 사용한다.
- 고정 top chrome과 scroll content 사이는 `AppTabLayoutMetrics.nonMapRootChromeBottomSpacing` 기본값을 공유한다.
- 산책 기록도 `nonMapRootPinnedHeaderLayout()` 기본값을 따라 같은 상단 리듬을 사용한다.
- 화면별 임시 bottom spacer로 viewport를 맞추지 않는다.

## 회귀 검증
- 정적 체크: `swift scripts/tabbar_card_surface_viewport_density_unit_check.swift`
- 기능 회귀:
  - `FeatureRegressionUITests/testFeatureRegression_TabBarUsesCompactCardSurfaceWithoutHeavyBand`
  - `FeatureRegressionUITests/testFeatureRegression_NonMapTabRootHeadersStayBelowStatusBar`
  - `FeatureRegressionUITests/testFeatureRegression_WalkListPrimaryContentIsNotObscuredByTabBar`
  - `FeatureRegressionUITests/testFeatureRegression_SettingsProductSectionsExposeOperationalEntries`

## 기대 결과
- 하단 탭바가 화면 전체 gradient band처럼 보이지 않는다.
- 네 비지도 탭 모두 첫 화면에서 본문 높이가 더 넓고 덜 답답하게 느껴진다.
- 마지막 카드/버튼은 여전히 탭바와 겹치지 않는다.
