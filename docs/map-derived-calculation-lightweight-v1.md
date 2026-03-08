#477 Map Derived Calculation Lightweight v1

## 배경
- `#477`은 지도 화면의 route/mark 파생 계산, heatmap 집계, hotspot cluster 재버킷팅, motion ticker 계층이 서로 겹치며 만드는 렌더/계산 비용을 줄이는 umbrella 이슈입니다.
- 실제 구현은 하위 사이클에서 나눠 반영되었습니다.
  - `#476` walking root invalidation 축소
  - `#501` motion ticker layer split
  - `#502` route/mark snapshot cache
  - `#503` heatmap trigger gating
  - `#504` hotspot cluster trigger gating

## 목표
- 지도에 보이는 route polyline, mark annotation, heatmap, hotspot cluster의 시각 의미를 유지합니다.
- 같은 source data에 대한 중복 파생 계산을 줄입니다.
- unrelated refresh, heartbeat, 숨김 상태 때문에 전체 재계산이 다시 돌지 않도록 게이트합니다.
- 무거운 집계는 가능하면 메인 스레드 점유를 줄이는 방향으로 분리합니다.

## 적용 요약

### 1. Route / Mark snapshot 재사용
- `MapWalkPointSnapshot`과 `MapWalkPointSnapshotService`를 도입했습니다.
- 동일 render 안에서
  - route 개수 판정
  - polyline 표시
  - mark annotation 표시
  가 같은 snapshot을 공유합니다.
- active walk append-only 경로는 마지막 포인트만 증분 반영합니다.

### 2. Heatmap trigger gating
- `MapHeatmapAggregationService`가 fingerprint와 freshness bucket을 기준으로 재집계를 게이트합니다.
- heatmap이 숨김 상태면 집계 task를 취소하고 presentation만 비웁니다.
- 동일 입력과 같은 `15분 bucket`이면 snapshot을 재사용합니다.
- 실제 집계는 background task에서 수행합니다.

### 3. Hotspot cluster trigger gating
- `MapHotspotClusterRenderingService`가
  - dataset fingerprint
  - viewport fingerprint
  - tuning fingerprint
  를 기준으로 재계산 여부를 판정합니다.
- 동일 fingerprint면 기존 snapshot을 재사용하고 `renderableNearbyHotspotNodes` 재 publish도 생략합니다.

### 4. Motion / ticker 계층 분리
- `MapSubView` 루트에서 ticker-driven state를 제거했습니다.
- cluster pulse, trail marker, render budget HUD를 leaf/sub-overlay 계층으로 내렸습니다.
- walking elapsed time도 루트 invalidation이 아니라 국소 timeline으로 표시합니다.

## Before / After 근거

### Route / Mark
- Before
  - 단일 polygon 상세 render에서 같은 `polygon.locations` 기준 파생 호출 최소 `3회`
    - `routeCoordinates(...).count`
    - `routeCoordinates(...)`
    - `markLocations(...)`
- After
  - 같은 render에서 snapshot 생성 `1회`
  - route 개수 판정, polyline, mark annotation이 동일 snapshot 재사용

### Heatmap
- Before
  - 같은 입력에서 `applyPolygonList()` 후 `applyFeatureFlags()`가 이어지면 전체 집계 최소 `2회`
  - heatmap 숨김 상태에서도 전체 히스토리 재집계 경로 존재
- After
  - heatmap 숨김 상태면 전체 집계 `0회`
  - heatmap 노출 상태에서도 fingerprint + `15분 bucket`이 같으면 추가 집계 `0회`
  - 집계는 background task로 이동

### Hotspot Cluster
- Before
  - `0.9초 heartbeat`만 지나도 hotspot cluster 재계산 최소 `1회` 가능
  - 동일 hotspot 입력 재대입에도 hotspot cluster 재계산 최소 `1회` 가능
- After
  - dataset / viewport / tuning fingerprint 동일 시 hotspot cluster 재계산 `0회`
  - 동일 snapshot이면 노드 재 publish도 `0회`

### Motion / Root invalidation
- Before
  - `MapSubView` 내부 `TimelineView` 개수 `2`
  - 250ms ticker만으로 3초 구간 최소 `12회` root reevaluation 원인 존재
- After
  - `MapSubView` 내부 `TimelineView` 개수 `0`
  - 안정화된 산책 상태 `3.2초` 측정값 `count = 0`
  - 회귀 기준 `3초 동안 count <= 6`
  - 최근 UI 회귀 측정 `mapSubViewBodyCount=2`

## 행동 보존 정리
- route 좌표 순서 유지
- mark 개수/순서 유지
- heatmap 계산식과 geohash precision 유지
- hotspot grouping 의미와 viewport/tuning 규칙 유지
- cluster merge/decompose pulse, capture ripple, trail marker 시각 효과 유지

## 메인 스레드 안전성
- heatmap 집계는 `Task.detached(priority: .utility)`로 분리했습니다.
- cluster / route / mark / motion 최적화는 알고리즘 자체가 아니라 trigger gate와 재사용 경로를 조정하는 방식으로 적용했습니다.
- 따라서 ordering bug나 결과 flicker 없이 deterministic update 경로를 유지합니다.

## 회귀 게이트
- `swift scripts/map_derived_calculation_lightweight_unit_check.swift`
- `swift scripts/map_walk_point_snapshot_cache_unit_check.swift`
- `swift scripts/map_heatmap_trigger_gating_unit_check.swift`
- `swift scripts/map_hotspot_cluster_trigger_gating_unit_check.swift`
- `swift scripts/map_motion_ticker_layer_split_unit_check.swift`
- `swift scripts/map_walking_invalidation_reduction_unit_check.swift`

## 관련 문서
- `docs/map-walk-point-snapshot-cache-v1.md`
- `docs/map-heatmap-trigger-gating-v1.md`
- `docs/map-hotspot-cluster-trigger-gating-v1.md`
- `docs/map-motion-ticker-layer-split-v1.md`
- `docs/map-walking-invalidation-reduction-v1.md`

## 결론
- `#477`의 완료 조건은 하위 최적화로 모두 충족되었습니다.
- 이번 문서는 그 결과를 umbrella 기준으로 고정하고, 이후 지도 파생 계산 회귀가 다시 들어오지 않도록 단일 게이트를 추가하는 역할을 합니다.
