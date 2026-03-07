import Foundation

func load(_ path: String) -> String {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(path)
    return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
}

func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let doc = load("docs/walk-widget-pet-context-policy-v1.md")
let snapshotStore = load("dogArea/Source/WidgetBridge/WalkWidgetSnapshotStore.swift")
let intents = load("dogAreaWidgetExtension/WalkControlIntents.swift")
let widgetView = load("dogAreaWidgetExtension/Widgets/WalkControlWidget.swift")
let mapWidgetSupport = load("dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WidgetRuntimeSupport.swift")
let rootView = load("dogArea/Views/GlobalViews/BaseView/RootView.swift")
let readme = load("README.md")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(doc.contains("# Walk Widget Pet Context Policy v1"), "doc should define walk widget pet context policy")
assertTrue(doc.contains("selected_pet_immediate"), "doc should define immediate selected pet policy")
assertTrue(doc.contains("fixed_pet_reserved"), "doc should reserve fixed pet policy")
assertTrue(doc.contains("contextId"), "doc should define action routing with contextId")

assertTrue(snapshotStore.contains("enum WalkWidgetStartPolicy"), "snapshot store should define start policy enum")
assertTrue(snapshotStore.contains("enum WalkWidgetPetContextSource"), "snapshot store should define pet context source enum")
assertTrue(snapshotStore.contains("struct WalkWidgetPetContext"), "snapshot store should define pet context model")
assertTrue(snapshotStore.contains("let petContext: WalkWidgetPetContext?"), "walk widget snapshot should persist pet context")
assertTrue(snapshotStore.contains("var normalizedPetContext: WalkWidgetPetContext"), "walk widget snapshot should normalize pet context")
assertTrue(snapshotStore.contains("legacyFallback"), "snapshot store should preserve backward compatibility for legacy snapshots")

assertTrue(intents.contains("snapshot.normalizedPetContext.petId"), "start intent should pin current widget pet context into contextId")
assertTrue(intents.contains("petContext: current.petContext ?? current.normalizedPetContext"), "pending route persistence should preserve pet context")

assertTrue(widgetView.contains("private var petContext: WalkWidgetPetContext"), "widget view should read normalized pet context")
assertTrue(widgetView.contains("petContext.detailText"), "widget view should show pet context description")
assertTrue(widgetView.contains("앱에서 반려견 확인"), "widget view should expose app-open CTA when no active pet exists")
assertTrue(widgetView.contains("petContext.badgeTitle"), "widget view should expose pet context badge")

assertTrue(mapWidgetSupport.contains("currentWalkWidgetStartPolicy() -> WalkWidgetStartPolicy"), "map widget support should resolve current start policy")
assertTrue(mapWidgetSupport.contains("resolveWalkWidgetPetContext() -> WalkWidgetPetContext"), "map widget support should resolve current widget pet context")
assertTrue(mapWidgetSupport.contains("resolveIdleWalkWidgetPetContext(from userInfo: UserInfo?) -> WalkWidgetPetContext"), "map widget support should define idle pet context fallback rules")
assertTrue(mapWidgetSupport.contains("applyWidgetRequestedPetContextIfNeeded(_ route: WalkWidgetActionRoute) -> WalkWidgetPetContext"), "map widget support should apply pinned widget pet context before start")
assertTrue(mapWidgetSupport.contains("route.contextId"), "map widget support should inspect route contextId")
assertTrue(mapWidgetSupport.contains("\"reason\": \"no_active_pet\""), "map widget support should reject start when no active pet exists")
assertTrue(mapWidgetSupport.contains("petContext: petContext"), "map widget support should save resolved pet context into snapshot")

assertTrue(rootView.contains("petContext: current.petContext ?? current.normalizedPetContext"), "root view should preserve pet context when only action state changes")
assertTrue(readme.contains("docs/walk-widget-pet-context-policy-v1.md"), "README should link the widget pet context policy doc")
assertTrue(iosPRCheck.contains("walk_widget_pet_context_policy_unit_check.swift"), "ios_pr_check should include widget pet context policy checks")

print("PASS: walk widget pet context policy unit checks")
