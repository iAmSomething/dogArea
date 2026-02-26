# Map LOD Clustering v1

## 1. 목적
지도 폴리곤 누적(500/1000/2000건) 상황에서 줌 레벨별 렌더링 비용을 낮추고, 줌아웃 구간의 시인성을 유지한다.

연결 이슈:
- 문서/구현: #73

## 2. 설계 원칙
- 원본 산책 데이터(`Polygon.locations`)는 그대로 유지한다.
- 표시 레이어만 LOD(Level of Detail)로 경량화한다.
- 클러스터 계산은 전수 비교(O(n²))가 아닌 버킷 집계(O(n))를 사용한다.

## 3. LOD 임계치(v1)
- `overlayMaxCameraDistance`: `4500m`
  - 카메라 거리가 이 값보다 크면 전체 폴리곤 오버레이를 생략한다.
- `overlayClusterThreshold`: `24`
  - 클러스터 수가 이 값보다 많으면 전체 폴리곤 오버레이를 생략한다.
- `overlayPolygonCountThreshold`: `900`
  - 전체 폴리곤 수가 이 값보다 많으면 전체 폴리곤 오버레이를 생략한다.
- `singleClusterOverlayLimit`: `160`
  - LOD 모드에서 단일 클러스터(1:1) 폴리곤만 최대 160개까지 렌더한다.
- `clusterCellSizeRange`: `80m ... 500m`
  - `clusterCellSize = clamp(cameraDistance * 0.08, 80, 500)`

## 4. 클러스터링 알고리즘(v1)
- 입력: 폴리곤 중심 좌표 리스트
- 방식:
  - 좌표를 `MKMapPoint`로 변환
  - 카메라 거리 기반 cell size(m)를 map point 단위로 환산
  - `(x/cell, y/cell)` 버킷 키로 집계
  - 같은 키에 속한 항목을 하나의 `Cluster`로 병합
- 복잡도:
  - 시간: O(n)
  - 공간: O(k), `k = bucket count`

## 5. 렌더링 규칙(v1)
- 산책 중(`showOnlyOne == true`)은 기존 단일 산책 오버레이 정책 유지
- 전체 보기 모드:
  - `shouldRenderFullPolygonOverlays == true`:
    - 전체 폴리곤 오버레이 렌더
  - `false`:
    - 클러스터 마커 중심으로 렌더
    - 단일 클러스터 항목만 선택적으로 오버레이 렌더

## 6. 회귀 체크 포인트
- 1000개 이상 폴리곤에서 줌아웃/팬 시 조작 지연이 완화되는지 확인
- 줌아웃 시 마커 가독성(겹침 감소) 확인
- 줌인 시 개별 폴리곤 접근성 유지 확인
- 단일 보기/전체 보기 전환 시 selected polygon 동기화 확인
