# Issue #476 Closure Evidence v1

## 대상
- issue: `#476`
- title: `산책 중 4Hz 지도 invalidation 제거`

## 구현 근거
- 구현 PR: `#560`
- 핵심 문서:
  - `docs/map-walking-invalidation-reduction-v1.md`
- 핵심 구현 파일:
  - `dogArea/Views/MapView/MapSubViews/MapSubView.swift`
  - `dogArea/Views/MapView/MapSubViews/MapWalkActiveValueCardView.swift`
  - `dogArea/Views/MapView/MapView.swift`
  - `dogArea/Views/MapView/MapViewModel.swift`
  - `dogArea/Views/MapView/MapSubViews/MapRenderBudgetProbeOverlayView.swift`

## DoD 판정
### 1. 지도 루트의 250ms ticker가 제거됨
- 기존 `MapSubView` 루트의 `motionTicker`/`motionNow` 구조가 제거됐다.
- 산책 중 4Hz invalidation 원인이던 루트 시간 구동 상태가 더 이상 존재하지 않는다.
- 판정: `PASS`

### 2. 시간/애니메이션 invalidation이 leaf 계층으로 격리됨
- ripple, trail marker, elapsed time이 각각 전용 subview 또는 timeline으로 내려갔다.
- `MapRenderBudgetProbeOverlayView`도 지도 본체 바깥 overlay 계층으로 분리됐다.
- 판정: `PASS`

### 3. 위치 publish도 의미 있는 변화일 때만 반영됨
- `publishMapLocationIfNeeded` / `shouldPublishMapLocation` 경로가 추가돼 위치 업데이트가 바로 루트 invalidation으로 번지지 않도록 정리됐다.
- 판정: `PASS`

### 4. render budget 회귀 기준이 문서와 테스트로 고정됨
- 설계 문서는 안정화 이후 3.2초 구간 `count = 0`, 회귀 기준 `3초 동안 count <= 6`을 명시한다.
- UI 회귀 테스트와 정적 체크가 이 기준을 계속 감시한다.
- 판정: `PASS`

## 검증 근거
- 정적 체크
  - `swift scripts/map_walking_invalidation_reduction_unit_check.swift`
  - `swift scripts/map_motion_ticker_layer_split_unit_check.swift`
  - `swift scripts/issue_476_closure_evidence_unit_check.swift`
- UI 회귀 기준
  - `dogAreaUITests/FeatureRegressionUITests.testFeatureRegression_MapWalkingRuntimeKeepsRootRenderCountBelowThreshold`
- 저장소 게이트
  - `DOGAREA_SKIP_BUILD=1 DOGAREA_SKIP_WATCH_BUILD=1 bash scripts/ios_pr_check.sh`

## 결론
- `#476`의 요구사항은 구현, 문서, 회귀 기준, 정적 체크 근거까지 확보됐다.
- 이 문서를 기준으로 `#476`은 종료 가능하다.
