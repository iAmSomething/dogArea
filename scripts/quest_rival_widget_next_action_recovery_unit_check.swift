import Foundation

@discardableResult
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() == false {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
    return true
}

func load(_ path: String) -> String {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(path)
    guard let data = try? Data(contentsOf: url),
          let string = String(data: data, encoding: .utf8) else {
        fputs("Failed to load \(path)\n", stderr)
        exit(1)
    }
    return string
}

let bridge = load("dogArea/Source/WidgetBridge/WalkWidgetBridge.swift")
let intents = load("dogAreaWidgetExtension/WalkControlIntents.swift")
let widget = load("dogAreaWidgetExtension/Widgets/QuestRivalStatusWidget.swift")
let rootView = load("dogArea/Views/GlobalViews/BaseView/RootView.swift")
let homeStates = load("dogArea/Views/HomeView/HomeViewModelSupport/HomePresentationStateModels.swift")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let tests = load("dogAreaUITests/FeatureRegressionUITests.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")
let doc = load("docs/quest-rival-widget-next-action-recovery-v1.md")

assertTrue(bridge.contains("case openQuestDetail = \"open_quest_detail\""), "bridge should define openQuestDetail route")
assertTrue(bridge.contains("case openQuestRecovery = \"open_quest_recovery\""), "bridge should define openQuestRecovery route")

assertTrue(intents.contains("struct OpenQuestDetailIntent"), "widget intents should define quest detail intent")
assertTrue(intents.contains("struct OpenQuestRecoveryIntent"), "widget intents should define quest recovery intent")
assertTrue(intents.contains("status: QuestRivalWidgetSnapshotStatus = contextId == nil ? .claimFailed : .claimInFlight"), "claim intent should mark mismatch as claimFailed")

assertTrue(widget.contains("private func primaryActionKind"), "quest/rival widget should derive primary action from snapshot state")
assertTrue(widget.contains("private func secondaryActionKind"), "quest/rival widget should derive secondary action from snapshot state")
assertTrue(widget.contains("보상까지"), "quest/rival widget should expose remaining progress copy")
assertTrue(widget.contains("앱에서 마무리"), "quest/rival widget should expose recovery CTA copy")
assertTrue(widget.contains("퀘스트 상세 보기"), "quest/rival widget should expose quest detail CTA copy")

assertTrue(homeStates.contains("case questMissionBoard = \"quest_mission_board\""), "home external route should support quest mission board")
assertTrue(homeStates.contains("struct QuestWidgetEntryContext"), "home route state should define quest widget entry context")

assertTrue(rootView.contains("dispatchQuestWidgetRoute"), "root view should route quest widget actions into home mission board")
assertTrue(rootView.contains("destination: .questMissionBoard"), "root view should open home quest mission board destination")

assertTrue(homeView.contains("home.quest.externalRouteBanner"), "home view should expose quest widget banner accessibility identifier")
assertTrue(homeView.contains(".id(HomeExternalScrollTarget.questMissionSection.rawValue)"), "home view should mark quest section as scroll target")
assertTrue(homeView.contains("pendingHomeScrollTarget = .questMissionSection"), "home view should scroll quest section for widget route")

assertTrue(tests.contains("testFeatureRegression_QuestWidgetRouteOpensQuestMissionBoard"), "ui tests should cover quest widget detail route")
assertTrue(tests.contains("testFeatureRegression_QuestWidgetRecoveryRouteOpensQuestMissionBoard"), "ui tests should cover quest widget recovery route")

assertTrue(readme.contains("docs/quest-rival-widget-next-action-recovery-v1.md"), "README should index quest/rival widget next action doc")
assertTrue(prCheck.contains("swift scripts/quest_rival_widget_next_action_recovery_unit_check.swift"), "ios_pr_check should run quest/rival widget next action check")
assertTrue(doc.contains("앱에서 마무리") && doc.contains("퀘스트 상세 보기"), "doc should define separated recovery/detail CTAs")

print("PASS: quest rival widget next action recovery unit checks")
