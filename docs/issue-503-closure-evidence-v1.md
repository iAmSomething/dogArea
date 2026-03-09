# Issue #503 Closure Evidence v1

## 대상
- issue: `#503`
- title: `heatmap 재계산 trigger gating과 build 경량화`

## 구현 근거
- 구현 PR: `#562`
- 핵심 문서:
  - `docs/map-heatmap-trigger-gating-v1.md`
- 핵심 구현 파일:
  - `dogArea/Source/Domain/Map/Models/MapHeatmapSnapshot.swift`
  - `dogArea/Source/Domain/Map/Services/MapHeatmapAggregationService.swift`
  - `dogArea/Views/MapView/MapViewModel.swift`
  - `dogArea/Views/MapView/MapSubViews/MapSubView.swift`
  - `dogArea/Views/MapView/MapView.swift`

## DoD 판정
### 1. 동일 입력에서 heatmap 전체 재집계가 반복되지 않음
- `MapHeatmapDatasetFingerprint`와 `MapHeatmapAggregationSnapshot`이 도입되어 동일 polygon/location 입력을 식별한다.
- `MapViewModel.refreshHeatmap(...)`는 fingerprint와 시간 버킷이 같으면 기존 snapshot을 재사용한다.
- 판정: `PASS`

### 2. heatmap이 실제로 보이지 않는 상태에서는 계산이 중단됨
- `isHeatmapVisibleInMapUI`가 feature flag, 사용자 토글, 산책 중 여부, 단일 영역 보기 여부를 하나의 규칙으로 묶는다.
- 숨김 상태에서는 `clearHeatmapPresentation(preserveSnapshot: true)`를 통해 진행 중 집계를 취소하고 화면 셀만 비운다.
- 판정: `PASS`

### 3. 집계는 메인 스레드 밖에서 수행되고 최신 요청만 반영됨
- `MapHeatmapAggregationService`는 `Task.detached(priority: .utility)`에서 집계를 수행한다.
- `MapViewModel`은 `latestHeatmapRefreshRequestID`와 snapshot fingerprint를 확인한 최신 결과만 적용한다.
- 판정: `PASS`

### 4. heatmap 표시 의미는 유지되고, 재계산 빈도만 줄어듦
- geohash precision과 `HeatmapEngine.aggregate(...)` 계산식은 그대로 유지된다.
- 정책 문서는 `최소 2회 -> 숨김 상태 0회`, `15분 bucket` 재사용 규칙을 명시한다.
- 판정: `PASS`

## 검증 근거
- 정적 체크
  - `swift scripts/map_heatmap_trigger_gating_unit_check.swift`
  - `swift scripts/issue_503_closure_evidence_unit_check.swift`
- 저장소 게이트
  - `DOGAREA_SKIP_BUILD=1 DOGAREA_SKIP_WATCH_BUILD=1 bash scripts/ios_pr_check.sh`

## 결론
- `#503`의 요구사항은 구현, 문서, 정적 체크 근거까지 확보됐다.
- 이 문서를 기준으로 `#503`은 종료 가능하다.
