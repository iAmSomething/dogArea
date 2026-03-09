# Map Bottom Controller Anchored Density v1

## 목표
- 지도 하단 산책 컨트롤러를 `floating card`가 아니라 `anchored control bar`로 읽히게 만든다.
- idle / walking 상태별로 서로 다른 세로 footprint budget을 둔다.
- 선택 트레이, 우측 floating controls, add-point 버튼과 같이 떠도 하단 stack이 두껍게 느껴지지 않게 한다.

## 레이아웃 계약
- idle 컨트롤 바 surface 높이 budget: `<= 124pt`
- walking 컨트롤 바 surface 높이 budget: `<= 112pt`
- 컨트롤 바와 탭바 상단 사이 gap: `4pt ... 36pt`
- walking 상태는 idle보다 더 얇아야 하며, 진행 설명은 별도 full-width 카드가 아니라 deck 내부 compact card로 축약한다.
- 시작/종료/add-point 동작 로직은 유지한다.

## 구조 결정
- `MapBottomControlOverlayView`는 하단 바닥 여백과 tray / floating control spacing만 책임진다.
- `StartButtonView`는 단일 anchored surface 안에서
  - 좌측 context card
  - 중앙 primary CTA
  - 우측 compact helper card
  구조를 유지한다.
- 산책 중 full-width `MapWalkActiveValueCardView`는 제거하고, 같은 식별자를 유지한 compact card로 우측 영역에 편입한다.
- idle 의미 설명은 `설명 보기` affordance를 남기되 inline card로 유지한다.

## 시각 방향
- 그림자 반경과 y-offset을 줄여 탭바 인접 dock 느낌을 우선한다.
- corner radius는 기존 map chrome surface보다 작게 유지한다.
- 내부 pill padding도 12pt 중심이 아니라 10pt 전후로 줄인다.

## 자동 검증
- `FeatureRegressionUITests/testFeatureRegression_MapBottomControllerStaysAnchoredAndCompactAtRest`
- `FeatureRegressionUITests/testFeatureRegression_MapBottomControllerStaysAnchoredAndCompactWhileWalking`
- `swift scripts/map_bottom_controller_density_unit_check.swift`
