import Foundation

/// 조건이 거짓이면 실패 메시지를 stderr에 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건입니다.
///   - message: 조건이 거짓일 때 출력할 오류 메시지입니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let doc = load("docs/walk-widget-action-convergence-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let service = load("dogArea/Source/Domain/Map/Services/WalkWidgetActionConvergenceService.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let widgetRuntime = load("dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WidgetRuntimeSupport.swift")
let rootView = load("dogArea/Views/GlobalViews/BaseView/RootView.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapViewModelStore = load("dogArea/Views/GlobalViews/BaseView/MapViewModelStore.swift")
let widgetBridge = load("dogArea/Source/WidgetBridge/WalkWidgetBridge.swift")

for heading in [
    "# Walk Widget Action Convergence v1",
    "## 1. 정본 정의",
    "## 2. 액션 상태 수렴 규칙",
    "## 3. 딥링크와 pending 요청 중복 소비 규칙",
    "## 4. 앱 활성화 시 재동기화 규칙",
    "## 5. 관측성 규칙",
    "## 6. QA 체크포인트"
] {
    assertTrue(doc.contains(heading), "doc should contain heading \(heading)")
}

assertTrue(doc.contains("#617"), "doc should reference issue #617")
assertTrue(doc.contains("MapViewModel.isWalking"), "doc should define canonical app session source")
assertTrue(doc.contains("Live Activity"), "doc should define live activity convergence behavior")
assertTrue(doc.contains("map.walk.savedOutcome.card"), "doc should define the saved outcome card as the post-end app surface")
assertTrue(doc.contains("widget_action_pending_discarded"), "doc should define discard metric")
assertTrue(doc.contains("widget_action_converged"), "doc should define convergence metric")
assertTrue(doc.contains("widget_action_escalated"), "doc should define escalation metric")

assertTrue(service.contains("protocol WalkWidgetActionConverging"), "service should define convergence protocol")
assertTrue(service.contains("final class WalkWidgetActionConvergenceService"), "service should define convergence service")
assertTrue(service.contains("func resolve("), "service should expose resolve API")
assertTrue(service.contains("canonicalSuccessStateIfNeeded"), "service should define canonical success convergence helper")
assertTrue(service.contains("escalatedStateAfterPendingExpiry"), "service should define pending expiry escalation helper")

assertTrue(mapViewModel.contains("walkWidgetActionConvergenceService: WalkWidgetActionConverging"), "MapViewModel should inject convergence service")
assertTrue(widgetRuntime.contains("walkWidgetActionConvergenceService.resolve("), "widget runtime should resolve action state through convergence service")
assertTrue(widgetRuntime.contains("func reconcileWalkWidgetActionSurfacesOnAppActive()"), "widget runtime should expose app active reconciliation helper")
assertTrue(widgetRuntime.contains("trackWalkWidgetActionConvergenceIfNeeded"), "widget runtime should track convergence transitions")
assertTrue(widgetRuntime.contains("func enqueueWidgetWalkAction(_ route: WalkWidgetActionRoute)"), "widget runtime should queue widget actions until map runtime is active")
assertTrue(widgetRuntime.contains("func applyQueuedWidgetWalkActionIfPossible()"), "widget runtime should flush queued widget actions when runtime is active")
assertTrue(mapViewModelStore.contains("func queueWidgetWalkAction(_ route: WalkWidgetActionRoute)"), "map view model store should expose a queue helper for widget walk actions")
assertTrue(rootView.contains("mapViewModelStore.queueWidgetWalkAction(route)"), "RootView should queue walk widget actions directly into the map view model store")
assertTrue(mapView.contains("applyQueuedWidgetWalkActionIfPossible()"), "MapView should flush queued widget actions after runtime activation")
assertTrue(mapView.contains("walkWidgetActionRequested") == false, "MapView should no longer depend on notification-based widget action dispatch")

assertTrue(widgetBridge.contains("func pendingRequest() -> WalkWidgetActionRequest?"), "widget action request store should expose non-destructive pending read API")
assertTrue(widgetBridge.contains("func discardPending(matching actionId: String) -> Bool"), "widget action request store should expose matching discard API")
assertTrue(rootView.contains("widgetActionStore.pendingRequest()"), "RootView should load walk widget pending requests without clearing them first")
assertTrue(rootView.contains("widgetActionStore.discardPending(matching: route.actionId)"), "RootView should discard matching pending request when deep link is already parsed")
assertTrue(widgetRuntime.contains("widgetActionRequestStore.discardPending(matching: route.actionId)"), "Map widget runtime should acknowledge pending walk actions when they actually apply")
assertTrue(rootView.contains("reconcileWalkWidgetActionSurfacesIfPossible()"), "RootView should reconcile walk widget surfaces on app lifecycle events")

assertTrue(readme.contains("docs/walk-widget-action-convergence-v1.md"), "README should link convergence doc")
assertTrue(iosPRCheck.contains("walk_widget_action_convergence_unit_check.swift"), "ios_pr_check should run convergence unit check")

print("PASS: walk widget action convergence unit checks")
