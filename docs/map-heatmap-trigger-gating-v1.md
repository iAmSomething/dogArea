#503 Map Heatmap Trigger Gating

## 배경
- 변경 전 `MapViewModel.refreshHeatmap()`는 `HeatmapEngine.aggregate(...)`를 직접 호출했습니다.
- `applyPolygonList()`, `applyFeatureFlags()`, `toggleHeatmapEnabled()` 경로가 모두 같은 함수로 들어가면서, 실제 입력 데이터가 그대로여도 전체 heatmap 재집계를 다시 수행할 수 있었습니다.
- 특히 heatmap이 실제로 화면에 보이지 않는 상태(`산책 중`, `단일 영역 보기`, `feature off`, `사용자 toggle off`)에서도 `polygonList` 갱신이나 feature flag 재적용이 들어오면 전체 히스토리를 다시 훑는 구조였습니다.

## 구조 변경
- `MapHeatmapDatasetFingerprint` / `MapHeatmapAggregationSnapshot` 모델 추가
- `MapHeatmapAggregationService`로 fingerprint 생성, snapshot 재사용 판정, background 집계 책임 분리
- `MapViewModel`은 다음 책임만 유지
  - heatmap이 실제로 보이는 상태인지 판단
  - 현재 snapshot을 재사용할지 결정
  - 최신 요청 결과만 화면에 적용
- 집계 자체는 service 내부 `Task.detached(priority: .utility)`에서 수행해 메인 스레드 점유를 줄였습니다.

## Trigger Gating 규칙
- 재계산 허용 조건
  - `feature flag on`
  - `heatmapEnabled == true`
  - `isWalking == false`
  - `showOnlyOne == false`
- 동일 입력 재사용 조건
  - polygon/location fingerprint 동일
  - 현재 시각이 `15분 bucket` 안
- 숨김 상태에서는
  - 진행 중 집계 task 취소
  - `heatmapCells`만 비우고 snapshot은 유지
  - 다시 노출될 때 fingerprint가 같으면 즉시 재사용

## Before / After 근거

### 호출 빈도 관점
- Before
  - `applyPolygonList()`가 호출될 때마다 전체 heatmap 집계 `1회`
  - 같은 입력으로 `applyFeatureFlags()`가 이어지면 전체 heatmap 집계가 추가 `1회`
  - 즉, heatmap이 실제로 화면에 보이지 않는 상태에서도 동일 입력 기준 최소 `2회` 재집계 경로가 존재했습니다.
- After
  - 동일 시나리오에서 heatmap이 숨김 상태면 전체 집계 `0회`
  - heatmap이 보이는 상태라도 fingerprint와 15분 bucket이 같으면 추가 집계 `0회`
  - 최초 1회 계산 후에는 snapshot 재사용만 수행합니다.

### 메인 스레드 점유 관점
- Before
  - `MapViewModel.refreshHeatmap()`가 뷰모델 내부에서 즉시 `HeatmapEngine.aggregate(...)`를 실행했습니다.
- After
  - 실제 집계는 `MapHeatmapAggregationService` 내부 background task에서 수행됩니다.
  - `MapViewModel`은 계산 완료 후 snapshot 적용만 메인 스레드에서 처리합니다.

## 제품 의미 유지
- heatmap score 계산식은 기존 `HeatmapEngine.aggregate(points:now:precision:)`를 그대로 사용합니다.
- geohash precision도 기존과 같은 `7`을 유지합니다.
- 15분 bucket은 decay half-life가 21일인 현재 heatmap 의미를 바꾸지 않는 범위에서 재계산 빈도만 줄이기 위한 정책입니다.

## 회귀 방지 포인트
- `MapViewModel`에서 `HeatmapEngine.aggregate(...)`를 직접 다시 호출하지 말 것
- heatmap 표시 조건과 무관한 state 변경이 전체 집계를 일으키지 않도록 할 것
- time-based freshness를 더 촘촘하게 조정할 필요가 생기면 bucket 정책만 service에서 수정할 것
