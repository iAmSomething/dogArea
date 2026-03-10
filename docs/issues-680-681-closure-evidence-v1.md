# Issues #680 #681 Closure Evidence v1

## 대상
- issues: `#680`, `#681`
- theme: `authSessionDidChange main-safe delivery`, `logical auth transition coalescing`

## 구현 근거
### #680 background-thread publish runtime issue 수정
- `DefaultAuthSessionStore`는 이제 세션 저장 호출 thread에서 즉시 Notification을 발행하지 않는다.
- pending payload를 모은 뒤 `Task { @MainActor ... }` 경로로 `flushPendingSessionDidChangeIfNeeded()`를 호출해 main-safe하게 signal을 발행한다.
- root auth refresh는 `AuthFlowCoordinator.bindAuthSessionSync()` 하나가 담당하고, `dogAreaApp`의 중복 root observer는 제거됐다.
- 근거 문서:
  - `docs/auth-session-signal-contract-v1.md`

### #681 logical session transition 기준 중복 broadcast 정리
- 로그인/refresh 성공 경로는 `persistAuthenticatedSession(identity:tokenSession:)`로 identity + token 저장을 한 번의 logical transition으로 수렴한다.
- signal payload는 `reason`, `reasons`, `transition`을 유지하되, 같은 turn 안의 저장 단위 변경은 1개의 coalesced signal로 묶는다.
- settings / rival / map observer는 유지하되 main-safe observer 계약 위에서만 반응한다.
- 근거 문서:
  - `docs/auth-session-signal-contract-v1.md`

## DoD 판정
### 1. #680 runtime issue를 유발하던 off-main signal 발행이 제거됐다
- 세션 변경 Notification은 main actor에서만 발행한다.
- background thread에서 `@Published` 갱신을 유발하던 발행 경로를 store 내부에서 차단했다.
- 판정: `PASS`

### 2. #681 logical auth transition 1회당 signal이 1회로 수렴한다
- 로그인 성공과 refresh 성공은 identity/token을 따로따로 발행하지 않고 coalesced transition으로 저장한다.
- root observer 중복도 제거되어 같은 transition이 app root에서 다시 증폭되지 않는다.
- 판정: `PASS`

### 3. observer ownership과 signal contract가 저장소에 명시돼 있다
- `dogAreaApp`는 별도 `.authSessionDidChange` root observer를 두지 않는다.
- `AuthFlowCoordinator`가 root observer ownership을 가진다.
- observer ownership과 transition taxonomy가 문서와 정적 체크에 고정돼 있다.
- 판정: `PASS`

## 검증 근거
- 구현 PR
  - `#682` `fix: normalize auth session change signal delivery`
- 정적 체크
  - `swift scripts/auth_session_signal_contract_unit_check.swift`
  - `swift scripts/auth_flow_session_observer_unit_check.swift`
  - `swift scripts/settings_auth_session_sync_unit_check.swift`
  - `swift scripts/map_auth_session_sync_unit_check.swift`
  - `swift scripts/rival_auth_session_sync_unit_check.swift`
  - `swift scripts/issues_680_681_closure_evidence_unit_check.swift`
- 빌드/회귀
  - `xcodebuild -skipPackagePluginValidation -project dogArea.xcodeproj -scheme dogArea -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16,OS=18.5" build`
  - `DOGAREA_SKIP_BUILD=1 DOGAREA_SKIP_WATCH_BUILD=1 bash scripts/ios_pr_check.sh`

## 결론
- `#680`, `#681`은 구현과 회귀 기준이 저장소에 반영된 상태다.
- 이 문서를 기준으로 두 이슈를 함께 닫아도 된다.
