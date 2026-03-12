# Issue #690 Closure Evidence v1

## 대상
- issue: `#690`
- title: `시즌 타일 fill/stroke와 산책 polygon overlay의 렌더 우선순위·색 혼합 규칙 정리`

## 구현 근거
- 핵심 문서:
  - `docs/map-season-tile-occupation-visualization-v1.md`
- 핵심 구현 파일:
  - `dogArea/Views/MapView/MapSubViews/MapSubView.swift`
  - `dogArea/Views/MapView/MapViewModelSupport/MapViewModel+SeasonTileVisualPolicy.swift`

## DoD 판정
### 1. 시즌 타일이 stroke-first로 읽힌다
- `MapSeasonTileRenderScenario`를 도입해 fill/stroke를 상황별로 분리했다.
- fill은 보조 신호로만 유지하고, 점령/유지는 stroke가 주 신호가 되도록 정리했다.
- 판정: `PASS`

### 2. 시즌 타일과 산책 polygon/route의 레이어 우선순위가 명시된다
- `MapSubView`는 주석과 선언 순서로 다음 구조를 고정한다.
  - 시즌 fill
  - 저장 polygon surface
  - 시즌 stroke
  - 선택 halo
  - active route / marker
  - hit target / hotspot
- 판정: `PASS`

### 3. active route와 함께 보여도 muddy fill이 줄어든다
- `seasonOnly / seasonWithStoredPolygonSurface / seasonWithActiveWalkRoute` 시나리오별로 fill opacity를 다르게 적용한다.
- active route와 함께 보일 때 fill과 저장 polygon fill을 더 약하게 내려 주 레이어 경쟁을 줄인다.
- 판정: `PASS`

### 4. 선택 상태는 fill darkening 없이 outline으로만 강조한다
- 선택은 `seasonTileSelectionHaloColor`와 `seasonTileSelectionHaloStyle`만으로 강조한다.
- hit target은 `Color.clear`를 사용해 시각 흔적이 남지 않게 했다.
- 판정: `PASS`

## 검증 근거
- 정적 체크
  - `swift scripts/map_season_render_priority_compaction_unit_check.swift`
  - `swift scripts/map_season_tile_occupation_visualization_unit_check.swift`
  - `swift scripts/map_season_render_priority_stroke_first_unit_check.swift`
- 저장소 게이트
  - `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`

## 결론
- `#690`의 reopen 사유였던 `검게/짙게 채워진 fill`, `레이어 경쟁`, `stroke보다 fill이 먼저 읽히는 문제`를 코드와 문서 계약 기준으로 정리했다.
