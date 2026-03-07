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

let doc = load("docs/walk-widget-action-state-model-v1.md")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let snapshotStore = load("dogArea/Source/WidgetBridge/WalkWidgetSnapshotStore.swift")
let intents = load("dogAreaWidgetExtension/WalkControlIntents.swift")
let widgetView = load("dogAreaWidgetExtension/Widgets/WalkControlWidget.swift")
let rootView = load("dogArea/Views/GlobalViews/BaseView/RootView.swift")
let widgetRuntime = load("dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WidgetRuntimeSupport.swift")

for heading in [
    "# Walk Widget Action State Model v1",
    "## 2. 모델 분리 원칙",
    "## 3. 상태 모델",
    "## 4. 시작/종료 액션 전이",
    "## 5. 스냅샷 충돌 방지 규칙",
    "## 6. UI 규칙",
    "## 7. QA 체크포인트"
] {
    assertTrue(doc.contains(heading), "doc should contain heading \(heading)")
}

for token in [
    "pending",
    "requiresAppOpen",
    "succeeded",
    "failed",
    "retry",
    "openApp"
] {
    assertTrue(snapshotStore.contains(token), "snapshot store should define token \(token)")
}

assertTrue(snapshotStore.contains("enum WalkWidgetActionPhase"), "snapshot store should define action phase enum")
assertTrue(snapshotStore.contains("enum WalkWidgetActionFollowUp"), "snapshot store should define action follow-up enum")
assertTrue(snapshotStore.contains("struct WalkWidgetActionState"), "snapshot store should define action state model")
assertTrue(snapshotStore.contains("let actionState: WalkWidgetActionState?"), "walk widget snapshot should store action state separately")
assertTrue(snapshotStore.contains("timelineReloadSignature"), "walk widget snapshot should define a reload signature")
assertTrue(snapshotStore.contains("WalkWidgetBridgeContract.walkWidgetKind"), "walk snapshot store should reload only the walk widget kind")

assertTrue(intents.contains("struct OpenWalkTabIntent"), "widget intents should provide an open-app confirmation intent")
assertTrue(intents.contains("actionState: .pending"), "widget intents should persist pending action state immediately")
assertTrue(widgetView.contains("activeActionState"), "walk widget view should read the action state")
assertTrue(widgetView.contains("case .pending"), "walk widget view should present pending state")
assertTrue(widgetView.contains("OpenWalkTabIntent"), "walk widget view should expose open-app follow-up")
assertTrue(widgetView.contains("다시 시도"), "walk widget view should expose retry follow-up")
assertTrue(rootView.contains("case .openWalkTab"), "RootView should route open-walk-tab widget action")
assertTrue(rootView.contains("updateWalkWidgetActionState"), "RootView should update widget action state on deferred auth flow")
assertTrue(widgetRuntime.contains("actionStateOverride"), "map widget runtime should sync explicit action state overrides")
assertTrue(widgetRuntime.contains(".succeeded("), "map widget runtime should write success action state")
assertTrue(widgetRuntime.contains(".failed("), "map widget runtime should write failure action state")

assertTrue(doc.contains("#512"), "doc should reference issue #512")
assertTrue(readme.contains("docs/walk-widget-action-state-model-v1.md"), "README should link walk widget action state model doc")
assertTrue(iosPRCheck.contains("walk_widget_action_state_model_unit_check.swift"), "ios_pr_check should run walk widget action state model checks")

print("PASS: walk widget action state model unit checks")
