# Auth Session Signal Contract v1

- Issues: #680, #681

## 목적
- `authSessionDidChange`를 UI 전역 상태 동기화용 main-safe signal로 고정한다.
- 로그인/refresh처럼 하나의 논리적 세션 전환이 저장 단위 broadcast 여러 번으로 퍼지지 않도록 한다.

## 문제 정리
- 기존 구조는 `persist(identity)`와 `persist(tokenSession:)`가 각각 즉시 Notification을 발행했다.
- `SupabaseInfrastructure` refresh, `AuthUseCase.execute(...)` 로그인 성공 경로가 identity/token 저장을 연속 호출해 broadcast가 2회 발생할 수 있었다.
- `dogAreaApp`와 `AuthFlowCoordinator`가 같은 signal에 둘 다 `authFlow.refresh()`를 연결하고 있어 root refresh가 중복될 수 있었다.
- Notification 발행이 저장 호출 thread를 그대로 따라가면 `@Published` 갱신 체인에서 background-thread publish runtime issue가 날 수 있다.

## 계약
- `DefaultAuthSessionStore`는 저장/삭제 직후 즉시 Notification을 쏘지 않는다.
- signal은 항상 main actor에서만 발행한다.
- 같은 run loop turn 안에서 발생한 세션 저장 단위 변경은 1개의 pending signal로 coalescing한다.
- logical transition 단위 저장은 `persistAuthenticatedSession(identity:tokenSession:)`를 우선 사용한다.
- signal payload는 최소 아래 디버그 정보를 유지한다.
  - `reason`: 마지막 저장 이유
  - `reasons`: coalesced reason 배열
  - `transition`: `authenticated`, `token_acquired`, `token_refreshed`, `token_cleared`, `signed_out`, `identity_updated`, `session_updated`

## observer 원칙
- root auth refresh 책임은 `AuthFlowCoordinator.bindAuthSessionSync()` 하나로 수렴한다.
- `dogAreaApp`는 같은 signal에 별도 `authFlow.refresh()` observer를 다시 두지 않는다.
- 화면별 observer는 UI state 반영용으로만 유지하되, main queue 또는 main actor에서만 처리한다.

## 적용 범위
- `DefaultAuthUseCase.execute(...)`
- `SupabaseInfrastructure` refresh success / retry-with-refresh success 경로
- `dogAreaApp`
- `AuthFlowCoordinator`
- settings / rival / map auth session observer

## 완료 기준
- logical auth transition 1회당 signal이 1회로 수렴한다.
- signal 발행은 main-safe다.
- root auth refresh 중복 observer가 없다.
