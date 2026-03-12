# Issue #698 Closure Evidence v1

## 대상
- issue: `#698`
- title: `watch 메인 정보 화면과 산책 컨트롤 화면 페이지 분리`

## 구현 근거
- 구현 PR: `#741` 이후 control surface rehardening follow-up
- 핵심 문서:
  - `docs/watch-main-scroll-overflow-ux-v1.md`
  - `docs/watch-control-surface-density-v1.md`
- 핵심 구현 파일:
  - `dogAreaWatch Watch App/ContentView.swift`
  - `dogAreaWatch Watch App/WatchControlSurfaceView.swift`
  - `dogAreaWatch Watch App/WatchMainStatusSummaryView.swift`
  - `dogAreaWatch Watch App/WatchPrimaryActionDockView.swift`
  - `dogAreaWatch Watch App/WatchActionBannerView.swift`

## DoD 판정
### 1. 조작 화면과 정보 화면이 같은 주 화면에서 경쟁하지 않는다
- `ContentView`는 `TabView(selection: $selectedSurface)`로 `control / info` 두 페이지를 유지한다.
- 정보 화면은 `watch.main.info.header`를 통해 첫 줄부터 목적을 설명한다.
- 판정: `PASS`

### 2. 조작 화면이 overlay가 아니라 독립 surface처럼 읽힌다
- `WatchControlSurfaceView`는 `조작 화면` header, 현재 상태 badge, 최소 상태 요약, inline feedback, action section을 하나의 surface 안에 통합한다.
- `WatchPrimaryActionDockView`는 더 이상 dock 설명 카드를 따로 만들지 않고 action section으로 읽히게 정리됐다.
- 판정: `PASS`

### 3. control page 안에서도 작은 카드 층이 다시 생기지 않는다
- `WatchMainStatusSummaryView`의 메트릭은 `single metrics strip`으로 통합됐다.
- inline feedback는 stroke 중심의 얇은 상태 strip로 내려 separate card 인상을 줄였다.
- 판정: `PASS`

### 4. 정보 화면은 secondary information만 담당한다
- 반려견 문맥과 오프라인 큐 상태는 정보 화면에만 남고, control page에는 복귀하지 않는다.
- paging hint는 첫 방문 전까지만 노출된다.
- 판정: `PASS`

## 검증 근거
- 정적 체크
  - `swift scripts/watch_control_info_surface_split_unit_check.swift`
  - `swift scripts/watch_control_surface_density_unit_check.swift`
  - `swift scripts/watch_main_scroll_overflow_unit_check.swift`
  - `swift scripts/watch_control_surface_rehardening_unit_check.swift`
- watch build
  - `xcodebuild -project dogArea.xcodeproj -scheme 'dogAreaWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- 저장소 게이트
  - `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`

## 결론
- `#698`은 control/info surface 분리뿐 아니라, control page가 독립 조작 화면으로 읽히도록 한 번 더 rehardening 됐다.
- reopen 사유였던 `overlay처럼 떠 있다`는 인상을 줄이는 구조/문서/정적 체크 근거가 확보됐다.
