# #501 Map Motion Ticker Layer Split v1

## 배경
- 이전 `MapSubView.swift`는 지도 본체 파일 안에 다음 요소를 함께 들고 있었습니다.
  - cluster pulse를 위한 로컬 `@State`
  - trail marker용 `TimelineView`
  - render budget HUD용 `TimelineView`
- 즉, ripple/HUD/cluster pulse 같은 고주기 시각 요소가 지도 본체 파일에 함께 묶여 있었습니다.

## 변경 요약
- `MapClusterMotionState`를 추가해 cluster pulse 이벤트를 전용 상태 객체로 분리했습니다.
- cluster pulse UI는 `MapClusterPulseAnnotationView` leaf view로 옮겼습니다.
- trail marker 시각 효과는 `MapTrailMarkerAnnotationView`에서 `onAppear` 기반 lifetime animation으로 바꿨습니다.
- render budget HUD는 `MapRenderBudgetProbeOverlayView`로 분리하고 `MapView` 루트 overlay로 올렸습니다.
- render budget HUD는 `TimelineView` polling 대신 테스트가 명시적으로 샘플링하는 manual probe로 바꿨습니다.

## Before / After
### Before
- `MapSubView.swift` 내부 `TimelineView` 개수: `2`
- `MapSubView.swift` 내부 로컬 pulse 상태: `clusterPulseActive`
- cluster motion 이벤트가 `MapViewModel`의 `@Published token/transition`으로 전파됨

### After
- `MapSubView.swift` 내부 `TimelineView` 개수: `0`
- `MapSubView.swift` 내부 로컬 pulse 상태: `0`
- cluster motion 이벤트는 `MapClusterMotionState` leaf observer만 구독
- render budget HUD는 지도 본체 바깥 overlay 계층으로 분리
- render budget HUD는 `sample` 버튼으로만 값을 갱신해 probe 자체가 root invalidation을 유발하지 않음

## 유지한 동작
- 지도 카메라 이동/추적
- route/polyline/annotation overlay 표시
- cluster merge/decompose pulse
- capture ripple 표시
- trail marker fade-out
- render budget debug HUD

## 검증 근거
- 정적 체크: `swift scripts/map_motion_ticker_layer_split_unit_check.swift`
- UI 회귀:
  - `testFeatureRegression_MapPrimaryActionIsNotObscuredByTabBar`
  - `testFeatureRegression_MapAddPointControlRemainsHittableWhileWalking`
  - `testFeatureRegression_MapWalkingRuntimeKeepsRootRenderCountBelowThreshold`

## 측정 메모
- 변경 후 동일 budget 테스트에서 `mapSubViewBodyCount`는 `1`로 측정됐고, 지도 root tree 재평가가 ticker/HUD 분리 이후에도 기준치 이하임을 확인했습니다.
