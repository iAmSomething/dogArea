# Issue #738 Closure Evidence v1

## 대상
- issue: `#738`
- title: `운동 앱형 단일 목적 산책 control page로 재정의`

## 구현 근거
- 구현 PR: watch control page minimal surface closure cycle PR
- 핵심 문서:
  - `docs/watch-control-surface-density-v1.md`
  - `docs/watch-main-scroll-overflow-ux-v1.md`
- 핵심 구현 파일:
  - `dogAreaWatch Watch App/ContentView.swift`
  - `dogAreaWatch Watch App/WatchControlSurfaceView.swift`
  - `dogAreaWatch Watch App/WatchMainStatusSummaryView.swift`
  - `dogAreaWatch Watch App/WatchPrimaryActionDockView.swift`
  - `dogAreaWatch Watch App/WatchActionBannerView.swift`

## DoD 판정
### 1. control page는 단일 목적 조작 화면으로 읽힌다
- `WatchControlSurfaceView`는 header, 최소 상태 요약, action section만 남긴다.
- control page에는 반려견 문맥과 feedback banner가 다시 올라오지 않는다.
- 판정: `PASS`

### 2. control page에는 최소 상태만 남는다
- `WatchMainStatusSummaryView`는 `시간`, `포인트`, `연결` 3개만 노출한다.
- idle 상태에서도 반려견 문맥은 info page에서 확인한다.
- 판정: `PASS`

### 3. 정보 화면이 secondary information을 맡는다
- `ContentView`의 info page가 `WatchActionBannerView`, `WatchSelectedPetContextCardView`, `WatchOfflineQueueStatusCardView`를 순서대로 보여 준다.
- 사용자는 조작과 해석을 page 단위로 나눠 읽을 수 있다.
- 판정: `PASS`

## 검증 근거
- 정적 체크
  - `swift scripts/watch_control_info_surface_split_unit_check.swift`
  - `swift scripts/watch_control_surface_density_unit_check.swift`
  - `swift scripts/watch_action_feedback_ux_unit_check.swift`
  - `swift scripts/issue_738_closure_evidence_unit_check.swift`
- watch build
  - `xcodebuild -project dogArea.xcodeproj -scheme 'dogAreaWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- 저장소 게이트
  - `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`

## 결론
- `#738`의 핵심 요구였던 `운동 앱형 단일 목적 control page` 구조가 코드, 문서, 정적 체크 기준으로 확보됐다.
- control page는 조작에만 집중하고, 보조 정보는 info page로 분리됐다.
