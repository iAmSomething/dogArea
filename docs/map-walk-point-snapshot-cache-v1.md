#502 Map Walk Point Snapshot Cache

## 배경
- `MapSubView`는 같은 render 안에서 `routeCoordinates(for: viewModel.polygon)`를 `count` 확인과 실제 `MapPolyline` 그리기에 각각 호출했습니다.
- 같은 분기에서 `markLocations(for: viewModel.polygon)`도 별도로 호출해, 동일한 `polygon.locations`를 다시 순회했습니다.
- 활성 산책 세션도 route/mark 파생값을 route용과 mark용으로 나눠 각각 다시 계산할 수 있는 구조였습니다.

## 변경
- `MapWalkPointSnapshot` 모델을 추가해 route 좌표와 mark 포인트를 같은 snapshot으로 묶었습니다.
- `MapWalkPointSnapshotService`를 도입해 `Polygon`별 route/mark 파생값을 캐시합니다.
- append-only 경로에서는 마지막 포인트만 반영해 active walk snapshot을 갱신합니다.
- `MapSubView`는 `activeWalkPointSnapshot`, `walkPointSnapshot(for:)`를 한 번만 읽고 같은 render 안에서 재사용합니다.

## Before
- 단일 polygon 상세 분기에서 같은 `polygon.locations` 기준 호출이 최소 `3회`였습니다.
  - `routeCoordinates(...).count`
  - `routeCoordinates(...)`
  - `markLocations(...)`
- 각 호출은 내부적으로 `filter/map`를 다시 수행했습니다.

## After
- 단일 polygon 상세 분기에서 route/mark 파생 계산은 snapshot 생성 `1회`로 정리됩니다.
- active walk append-only 경로는 기존 snapshot에 마지막 포인트만 추가합니다.
- 동일 render 안에서는 route 개수 판정, polyline 그리기, mark annotation 반복이 같은 snapshot을 재사용합니다.

## 유지 조건
- route 좌표 순서 유지
- mark 포인트 개수와 표시 순서 유지
- polyline/annotation 시각 정책 유지
- 산책 중 포인트 추가 시 즉시 반영 유지

## 회귀 방지 포인트
- `MapSubView`에서 같은 polygon에 대해 `routeCoordinates(for:)` / `markLocations(for:)`를 중복 호출하지 말 것
- route/mark 파생은 `MapWalkPointSnapshotServicing`을 경유해 공유할 것
- append-only 최적화는 결과 변경이 없는 경우에만 적용할 것
