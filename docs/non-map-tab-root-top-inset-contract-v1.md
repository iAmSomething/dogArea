# Non-Map Tab Root Top Inset Contract v1

## 목적
- 비지도 탭 루트 화면(`홈`, `산책 기록`, `라이벌`, `설정`)이 status bar를 침범하지 않도록 공통 상단 inset 기준을 고정한다.
- 지도 탭은 풀블리드 시각 언어를 유지하는 예외 화면으로 명시한다.
- `#628`, `#622`, `#629`처럼 화면별로 반복되던 safe area 버그를 공통 scaffold 계약으로 흡수한다.

## 계약
- `appTabRootScrollLayout`을 사용하는 루트 화면의 기본 상단 inset은 `AppTabLayoutMetrics.nonMapRootTopSafeAreaPadding = 18`을 따른다.
- 비지도 탭 루트의 추가 조정은 기본적으로 `contentTopPadding` 같은 내부 콘텐츠 간격에서만 처리한다.
- 화면별로 `topSafeAreaPadding` override를 다시 넣는 것은 예외 사유가 명확할 때만 허용한다.
- `홈`, `산책 기록`, `라이벌`, `설정`은 모두 같은 기본 contract를 사용한다.
- 지도 탭은 `appTabRootScrollLayout` 공통 inset을 사용하지 않는다.
- 지도 상단 chrome은 `AppTabLayoutMetrics.topOverlaySpacing`과 `mapOverlayTopExtraSpacing` 계약을 따른다.

## 책임 분리
- `AppTabScaffold`
  - 비지도 탭 루트의 기본 top inset 계약을 가진다.
  - 하단 탭바 회피, 공통 배경, 루트 safe area 정책을 함께 담당한다.
- 화면별 헤더
  - 긴 제목/부제, Dynamic Type, 배지 줄바꿈 안정성을 담당한다.
  - status bar 회피 자체를 위해 루트 padding을 중복 보정하지 않는다.
- 지도 탭
  - 풀블리드 예외 화면으로 분리한다.
  - 상단 overlay spacing만 별도 계약으로 관리한다.

## 금지 사항
- 비지도 탭 화면마다 임시 top padding 수치를 따로 넣어 버그를 덮는 것
- 지도 탭까지 동일한 root top inset을 강제하는 것
- 헤더 래핑 문제를 루트 safe area 값으로 해결하려는 것

## 회귀 검증
- 정적 체크: `swift scripts/non_map_tab_root_top_inset_contract_unit_check.swift`
- UI 회귀: `FeatureRegressionUITests/testFeatureRegression_NonMapTabRootHeadersStayBelowStatusBar`
- 매트릭스: `FR-TABROOT-001` in `docs/ui-regression-matrix-v1.md`
