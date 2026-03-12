# Non-Map Custom Header Safe Area Contract v1

## 목적
- `navigation bar`를 숨기고 커스텀 헤더를 직접 그리는 비지도 루트 화면의 상단 시작 규칙을 공통화한다.
- 루트 safe area 예약과 고정 헤더 삽입은 `AppTabScaffold`, 첫 헤더 시작 간격은 `NonMapRootHeaderContainer`로 역할을 분리한다.
- `#678` 기준 화면인 `홈`, `산책 기록`, `라이벌`에 같은 패턴을 적용하고, `설정`도 동일 계약에 맞춘다.

## 화면 분류
- 지도(full-bleed) 화면
  - 공통 non-map root inset을 쓰지 않는다.
  - `MapTopChromeView`와 `AppTabLayoutMetrics.topOverlaySpacing` 계약을 따른다.
- inline navigation bar 상세 화면
  - 시스템 navigation bar가 상단 크롬을 맡는다.
  - 이 계약에 포함하지 않는다.
- 비지도 커스텀 헤더 루트 화면
  - `appTabRootScrollLayout(topSafeAreaPadding: 0)`로 빈 top inset을 제거하고
  - 일반 화면은 `nonMapRootTopChrome`, pinned section header 화면은 `nonMapRootPinnedHeaderLayout`으로 실제 헤더 chrome을 scroll content 밖 상단에 고정한다.

## 코드 계약
- `AppTabLayoutMetrics.nonMapRootTopSafeAreaPadding = 12`
  - 루트 safe area 예약은 여기서만 소유한다.
- `AppTabLayoutMetrics.nonMapRootHeaderTopSpacing = 8`
  - 첫 커스텀 헤더 블록이 safe area 예약 뒤에 시작하는 기본 간격이다.
- `AppTabLayoutMetrics.nonMapRootChromeBottomSpacing = 12`
  - 고정 헤더 chrome과 스크롤 본문 사이의 기본 리듬이다.
- `nonMapRootTopChrome`
  - 홈 첫 인사 헤더
  - 라이벌 헤더 + 첫 상태 배지 행
  - 설정 헤더
  를 scroll content 밖 상단 chrome으로 고정한다.
- `nonMapRootPinnedHeaderLayout`
  - 산책 기록처럼 `pinnedViews: [.sectionHeaders]`를 사용하는 화면에서 고정 chrome과 scroll 본문을 분리한다.
  - sticky section header가 루트 chrome 아래에 pin 되도록 scroll container 시작점을 구조적으로 분리한다.
- `NonMapRootTopChromeContainer`
  - `nonMapRootTopChrome`와 `nonMapRootPinnedHeaderLayout`이 내부에서 공통으로 사용하는 고정 상단 chrome 컨테이너다.
  - safe area 아래 배치와 header/body 리듬을 공통으로 유지한다.
- `NonMapRootHeaderContainer`
  - 고정 top chrome 안에서 첫 헤더 블록의 시작 간격만 담당한다.

## 금지 사항
- 화면별 `contentTopPadding`, `rootTopPadding`, `padding(.top, 24)` 같은 임시 수치로 첫 헤더 위치를 따로 맞추는 것
- 같은 패턴의 화면인데도 `nonMapRootTopChrome` 또는 `nonMapRootPinnedHeaderLayout` 대신 scroll content 첫 섹션에 헤더를 다시 넣는 것
- 지도와 inline navigation detail까지 같은 컨테이너를 강제하는 것

## 회귀 기준
- 홈/산책 기록/라이벌/설정의 첫 헤더가 status bar 아래에서 시작해야 한다.
- 홈/산책 기록/라이벌/설정의 첫 헤더는 스크롤해도 같은 `minY` 대역에 머물러야 한다.
- 긴 제목, 긴 부제, 큰 Dynamic Type에서도 헤더 본문과 배지/보조 카드가 겹치지 않아야 한다.
- sticky section header를 쓰는 산책 기록도 루트 예약 공간과 충돌하지 않아야 한다.

## 검증
- 정적 체크: `swift scripts/non_map_custom_header_safearea_contract_unit_check.swift`
- UI 회귀:
  - `FeatureRegressionUITests/testFeatureRegression_NonMapTabRootHeadersStayBelowStatusBar`
  - `FeatureRegressionUITests/testFeatureRegression_HomeHeaderStaysBelowStatusBarWithLongNames`
  - `FeatureRegressionUITests/testFeatureRegression_RivalHeaderStaysBelowStatusBarWithLongSubtitle`
  - `FeatureRegressionUITests/testFeatureRegression_WalkListStickySectionHeaderStaysBelowStatusBar`
