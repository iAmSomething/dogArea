# Issue #533 Closure Evidence v1

## 대상
- issue: `#533`
- title: `watch 메인 화면 콘텐츠 overflow 시 스크롤 불가`

## 구현 근거
- 구현 PR: `#558`
- 핵심 문서:
  - `docs/watch-main-scroll-overflow-ux-v1.md`
- 핵심 구현 파일:
  - `dogAreaWatch Watch App/ContentView.swift`
  - `dogAreaWatch Watch App/WatchMainStatusSummaryView.swift`
  - `dogAreaWatch Watch App/WatchPrimaryActionDockView.swift`
  - `dogAreaWatch Watch App/WatchActionButtonView.swift`

## DoD 판정
### 1. watch 메인 화면에서 overflow된 콘텐츠가 스크롤 가능하다
- 메인 화면이 `정보 스크롤 영역`과 `하단 CTA 도크`로 분리됐다.
- 상태/배너/반려견 문맥/큐 상태는 `ScrollView` 안에서 스크롤되도록 정리됐다.
- 판정: `PASS`

### 2. active walk와 idle 두 상태에서 모든 텍스트와 버튼 접근이 가능하다
- `WatchMainStatusSummaryView`가 상태 요약을 담당하고, `WatchPrimaryActionDockView`가 핵심 액션을 하단 도크로 고정한다.
- 작은 화면에서도 `산책 시작`, `영역 표시하기`, `산책 종료`가 화면 높이에 밀려 사라지지 않도록 `safeAreaInset(edge: .bottom)` 구조가 적용됐다.
- 판정: `PASS`

### 3. 작은 화면과 Dynamic Type 환경에서도 CTA가 잘리지 않는다
- CTA 버튼은 `minHeight 52pt` 이상과 multiline 허용 기준으로 설계됐다.
- 큐 상태 카드의 chip/action row는 `ViewThatFits` 기반 fallback을 갖는다.
- 판정: `PASS`

## 검증 근거
- 정적 체크
  - `swift scripts/watch_main_scroll_overflow_unit_check.swift`
  - `swift scripts/issue_533_closure_evidence_unit_check.swift`
- watch 빌드
  - `xcodebuild -project dogArea.xcodeproj -scheme 'dogAreaWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- 저장소 게이트
  - `DOGAREA_SKIP_BUILD=1 DOGAREA_SKIP_WATCH_BUILD=1 bash scripts/ios_pr_check.sh`

## 결론
- `#533`의 요구사항은 구현, 문서, 정적 체크 근거까지 모두 확보됐다.
- 이 문서를 기준으로 `#533`은 종료 가능하다.
