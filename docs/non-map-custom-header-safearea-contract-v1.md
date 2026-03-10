# Non-Map Custom Header Safe Area Contract v1

## 목적
- `navigation bar`를 숨기고 커스텀 헤더를 직접 그리는 비지도 루트 화면의 상단 시작 규칙을 공통화한다.
- 루트 safe area 예약은 `AppTabScaffold`, 첫 헤더 시작 간격은 `NonMapRootHeaderContainer`로 역할을 분리한다.
- `#678` 기준 화면인 `홈`, `산책 기록`, `라이벌`에 같은 패턴을 적용하고, `설정`도 동일 계약에 맞춘다.

## 화면 분류
- 지도(full-bleed) 화면
  - 공통 non-map root inset을 쓰지 않는다.
  - `MapTopChromeView`와 `AppTabLayoutMetrics.topOverlaySpacing` 계약을 따른다.
- inline navigation bar 상세 화면
  - 시스템 navigation bar가 상단 크롬을 맡는다.
  - 이 계약에 포함하지 않는다.
- 비지도 커스텀 헤더 루트 화면
  - `appTabRootScrollLayout`로 safe area 예약을 받고
  - 첫 헤더 블록은 `NonMapRootHeaderContainer`로 시작한다.

## 코드 계약
- `AppTabLayoutMetrics.nonMapRootTopSafeAreaPadding = 18`
  - 루트 safe area 예약은 여기서만 소유한다.
- `AppTabLayoutMetrics.nonMapRootHeaderTopSpacing = 12`
  - 첫 커스텀 헤더 블록이 safe area 예약 뒤에 시작하는 기본 간격이다.
- `NonMapRootHeaderContainer`
  - 홈 첫 인사 헤더
  - 산책 기록 대시보드 허브
  - 라이벌 헤더
  - 설정 헤더
  에 공통으로 사용한다.

## 금지 사항
- 화면별 `contentTopPadding`, `rootTopPadding`, `padding(.top, 24)` 같은 임시 수치로 첫 헤더 위치를 따로 맞추는 것
- 같은 패턴의 화면인데도 `NonMapRootHeaderContainer` 대신 개별 패딩을 다시 도입하는 것
- 지도와 inline navigation detail까지 같은 컨테이너를 강제하는 것

## 회귀 기준
- 홈/산책 기록/라이벌/설정의 첫 헤더가 status bar 아래에서 시작해야 한다.
- 긴 제목, 긴 부제, 큰 Dynamic Type에서도 헤더 본문과 배지/보조 카드가 겹치지 않아야 한다.
- sticky section header를 쓰는 산책 기록도 루트 예약 공간과 충돌하지 않아야 한다.

## 검증
- 정적 체크: `swift scripts/non_map_custom_header_safearea_contract_unit_check.swift`
- UI 회귀:
  - `FeatureRegressionUITests/testFeatureRegression_NonMapTabRootHeadersStayBelowStatusBar`
  - `FeatureRegressionUITests/testFeatureRegression_HomeHeaderStaysBelowStatusBarWithLongNames`
  - `FeatureRegressionUITests/testFeatureRegression_RivalHeaderStaysBelowStatusBarWithLongSubtitle`
  - `FeatureRegressionUITests/testFeatureRegression_WalkListStickySectionHeaderStaysBelowStatusBar`
