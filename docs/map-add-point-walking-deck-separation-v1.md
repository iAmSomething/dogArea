# Map Add-Point Walking Deck Separation v1

## 목적
- 산책 중 `+` 버튼과 우측 진행 deck이 같은 bottom anchor를 공유하면서 시각적으로 겹치는 문제를 제거한다.
- zIndex가 아니라 레이아웃 계약으로 add-point stack과 walking control bar footprint를 분리한다.

## 문제 정의
- `MapBottomControlOverlayView`는 `primaryAction`과 `floatingControls`를 같은 bottom overlay에서 padding 차이만으로 배치한다.
- walking 상태에서는 `MapWalkControlBarMetrics.walkingFootprintBudget`만큼의 deck가 바닥에서 차지되는데, add-point stack은 그 footprint를 모르고 같은 바닥 기준으로 렌더링된다.
- 결과적으로 `+` 버튼, `자동 기록`, `길게 0.4s` pill이 우측 진행 카드 위를 침범해 보일 수 있다.

## 레이아웃 계약
- `MapBottomControlOverlayView`는 `MapFloatingControlLayoutContext`를 받아 floating controls bottom padding을 계산한다.
- `showsAddPointButton == true`면 floating controls는 walking deck footprint 전체를 피해야 한다.
- walking deck separation 공식:
  - `basePadding = primaryActionBottomPadding(reservedHeight:)`
  - `requiredSeparation = MapWalkControlBarMetrics.walkingFootprintBudget + 14pt`
  - support badge(`자동 기록`, `길게 0.4s`)가 하나라도 보이면 `+10pt` buffer를 더한다.
- 최종 bottom padding은 `basePadding + max(requiredSeparation, floatingControlsBottomSpacingWhenPrimaryVisible)`를 사용한다.

## 의도한 결과
- `map.addPoint.stack`의 전체 프레임이 `map.walk.controlBar` 위에 고정된다.
- 작은 화면에서도 `+` 버튼이 우측 카드 텍스트/모서리 위를 침범하지 않는다.
- 향후 우측 보조 pill, add-point undo toast와 공존할 여유를 남긴다.

## 회귀 기준
- 정적 체크: `swift scripts/map_add_point_walking_deck_separation_unit_check.swift`
- UI 회귀:
  - `FeatureRegressionUITests/testFeatureRegression_MapAddPointControlRemainsHittableWhileWalking`
  - `FeatureRegressionUITests/testFeatureRegression_MapAddPointSupportStackClearsWalkingDeckFootprint`
