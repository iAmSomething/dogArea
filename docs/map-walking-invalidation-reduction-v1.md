#476 Map Walking Invalidation Reduction

## 원인 정리
- 변경 전 `MapSubView`는 `@State motionNow`와 `Timer.publish(every: 0.25, ...)`를 직접 보유했습니다.
- 이 구조 때문에 산책 중에는 포인트/카메라/배너 변경이 없어도 지도 루트 body가 250ms 주기로 다시 평가될 수 있었습니다.
- 동시에 `MapViewModel.time`이 `@Published`였기 때문에, 산책 시간 표시에 필요한 1초 갱신도 `MapView` 루트 invalidation으로 번졌습니다.

## 구조 변경
- 250ms 루트 ticker 제거
- capture ripple은 `MapCaptureRippleAnnotationView` 내부 `onAppear + animation`으로 국소화
- trail marker는 `MapTrailMarkerAnnotationView` 내부 `TimelineView`로 국소화
- 산책 시간 표시는 `StartButtonView` 내부 `MapWalkingElapsedTimeValueText`로 국소화
- `MapViewModel.time`은 내부 상태로만 유지하고, 화면 표시는 `displayedWalkElapsedTime(at:)`로 계산
- Core Location 샘플은 `publishMapLocationIfNeeded(_:)`에서 거리/시간/정확도 변화가 의미 있을 때만 `location` publish
- UI 테스트 전용 `MapRenderBudgetProbe`를 추가해 지도 루트 body count를 측정 가능하게 함

## 측정 방식
- 시나리오: `-UITest.MapForceWalkingState -UITest.TrackMapRenderBudget`
- 측정 구간: 지도 진입 후 `reset`으로 카운터를 초기화한 뒤, 안정화된 산책 상태 3.2초
- 지표: `MapSubView` root body evaluation count

## Before
- 코드 구조상 250ms ticker만으로도 3초 동안 최소 12회 루트 reevaluation 원인이 존재했습니다.
- 여기에 1초 단위 `time` publish가 별도로 겹칠 수 있어, 지도 루트 reevaluation이 데이터 변경과 무관하게 반복될 수 있었습니다.
- 위치 샘플도 들어오는 즉시 `location`을 publish해, 루트 reevaluation budget을 계속 밀어 올릴 수 있었습니다.

## After
- 실제 UI 회귀 테스트에서 동일 구간의 `MapSubView` root body count가 임계치 이하로 유지되는 것을 검증합니다.
- 2026-03-08 측정값: 안정화 이후 3.2초 구간 `count = 0`
- 회귀 기준: `3초 동안 count <= 6`
- 이 기준은 이전 구조의 4Hz 루트 invalidation(최소 12회/3초) 대비 절반 이하 budget을 강제합니다.

## 회귀 방지 포인트
- `MapSubView` 루트에 `motionTicker`, `motionNow` 같은 시간 구동 상태를 다시 두지 말 것
- 시간/애니메이션은 annotation 또는 metric subview 내부 timeline으로 격리할 것
- 새로운 지도 HUD 숫자/애니메이션을 추가할 때는 `MapRenderBudgetProbe` 기준을 먼저 확인할 것
