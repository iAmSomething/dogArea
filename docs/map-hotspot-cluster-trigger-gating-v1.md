#504 Map Hotspot Cluster Trigger Gating

## 배경
- 변경 전 `MapViewModel.refreshRenderableNearbyHotspots()`는 호출될 때마다 `clusterAnnotationService.renderHotspots(...)`를 직접 실행했습니다.
- 이 경로는 두 군데에서 쉽게 다시 들어왔습니다.
  - `recordCameraChange(...)`가 `cameraCacheMinUpdateInterval == 0.9초` heartbeat만으로 캐시를 갱신한 경우
  - `nearbyHotspots`에 이전과 동일한 배열이 다시 대입된 경우
- 결과적으로 카메라 거리/뷰포트/핫스팟 입력이 실질적으로 그대로여도 재버킷팅이 반복될 수 있었습니다.

## 변경
- `MapHotspotClusterDatasetFingerprint` / `MapHotspotClusterViewportFingerprint` / `MapHotspotClusterTuningFingerprint` 모델 추가
- `MapHotspotClusterRenderingService`를 도입해
  - dataset fingerprint 생성
  - viewport bucket 양자화
  - tuning fingerprint 고정
  - snapshot 재사용 판정
  - 실제 `renderHotspots(...)` 호출
  책임을 분리했습니다.
- `MapViewModel`은
  - 현재 입력과 뷰포트를 해석
  - snapshot 재사용 여부를 묻고
  - 새 계산이 필요한 경우에만 결과를 publish
  하도록 정리했습니다.

## Trigger Gating 규칙
- 재계산 허용 조건
  - `nearby hotspot feature on`
  - `nearbyHotspotEnabled == true`
  - dataset fingerprint 변경
  - viewport fingerprint 변경
  - tuning fingerprint 변경
- viewport fingerprint 구성
  - camera distance `80m bucket`
  - viewport radius 기반 center bucket
  - center bucket은 `24m ... 240m` 범위에서 동적으로 계산
- 동일 fingerprint면
  - 기존 snapshot의 노드를 그대로 재사용
  - `renderableNearbyHotspotNodes`를 다시 publish하지 않음

## Before / After 근거

### 재계산 횟수 관점
- Before
  - 카메라가 실제로 거의 그대로여도 `0.9초 heartbeat`만 지나면 hotspot cluster 재계산이 최소 `1회` 다시 발생할 수 있었습니다.
  - 동일한 hotspot 입력 배열이 다시 들어와도 hotspot cluster 재계산이 최소 `1회` 다시 발생할 수 있었습니다.
- After
  - heartbeat만 발생하고 dataset/viewport/tuning fingerprint가 같으면 hotspot cluster 재계산 `0회`입니다.
  - 동일 hotspot 입력이 다시 대입돼도 snapshot 재사용 경로로 묶여 hotspot cluster 재계산 `0회`입니다.

### 화면 안정성 관점
- Before
  - 동일 결과라도 `renderableNearbyHotspotNodes`를 다시 assign해 publish할 수 있었습니다.
- After
  - 같은 snapshot이면 publish를 생략합니다.
  - 따라서 flicker 없이 기존 노드 순서/그룹 의미를 그대로 유지합니다.

## 제품 의미 유지
- 실제 hotspot 노드 계산은 기존 `MapClusterAnnotationService.renderHotspots(...)`를 그대로 사용합니다.
- 후보 cap, viewport radius, cluster distance threshold, cell ratio 규칙은 바꾸지 않았습니다.
- 바뀐 것은 재계산을 시작하는 trigger gate뿐입니다.

## 회귀 방지 포인트
- `MapViewModel`에서 `clusterAnnotationService.renderHotspots(...)`를 직접 다시 호출하지 말 것
- hotspot 재계산 조건은 dataset/viewport/tuning fingerprint를 통해서만 늘릴 것
- 동일 snapshot에서는 노드를 다시 publish하지 말 것
