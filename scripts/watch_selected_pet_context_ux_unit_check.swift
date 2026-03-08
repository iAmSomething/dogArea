import Foundation

func read(_ path: String) -> String {
    (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
}

func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = FileManager.default.currentDirectoryPath
let readme = read(root + "/README.md")
let doc = read(root + "/docs/watch-selected-pet-context-ux-v1.md")
let watchView = read(root + "/dogAreaWatch Watch App/ContentView.swift")
let watchViewModel = read(root + "/dogAreaWatch Watch App/ContentsViewModel.swift")
let watchContextState = read(root + "/dogAreaWatch Watch App/WatchSelectedPetContextState.swift")
let watchContextCard = read(root + "/dogAreaWatch Watch App/WatchSelectedPetContextCardView.swift")
let mapWatchSupport = read(root + "/dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WatchConnectivitySupport.swift")
let mapWidgetSupport = read(root + "/dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WidgetRuntimeSupport.swift")
let mapViewModel = read(root + "/dogArea/Views/MapView/MapViewModel.swift")
let checkScript = read(root + "/scripts/ios_pr_check.sh")

assertTrue(readme.contains("watch-selected-pet-context-ux-v1.md"), "README should index watch selected pet context doc")
assertTrue(doc.contains("#521"), "doc should mention issue #521")
assertTrue(doc.contains("read-only"), "doc should define read-only decision")
assertTrue(doc.contains("context_id"), "doc should define start action context_id contract")
assertTrue(doc.contains("walking_locked"), "doc should describe walking locked state")
assertTrue(doc.contains("반려견 다시 확인"), "doc should document refresh affordance")

assertTrue(watchView.contains("WatchSelectedPetContextCardView"), "watch content should render selected pet context card")
assertTrue(watchViewModel.contains("@Published private(set) var petContext"), "watch view model should publish pet context state")
assertTrue(watchViewModel.contains("let contextId: String?"), "watch action dto should carry optional context id")
assertTrue(watchViewModel.contains("func refreshPetContext()"), "watch view model should expose refresh action")
assertTrue(watchViewModel.contains("petContext.blocksInlineStart"), "watch start flow should guard blocked inline start")

assertTrue(watchContextState.contains("struct WatchSelectedPetContextState"), "watch target should define selected pet context state")
assertTrue(watchContextState.contains("enum WatchSelectedPetContextSource"), "watch target should define selected pet context source enum")
assertTrue(watchContextState.contains("func showsRefreshAction"), "watch context state should decide refresh visibility")
assertTrue(watchContextCard.contains("반려견 다시 확인"), "watch context card should expose refresh button copy")

assertTrue(mapViewModel.contains("let requestedContextId: String?"), "app watch envelope should parse requested context id")
assertTrue(mapWatchSupport.contains("\"selected_pet_context\""), "watch support should publish selected pet context payload")
assertTrue(mapWatchSupport.contains("makeWatchSelectedPetContextPayload"), "watch support should build selected pet payload")
assertTrue(mapWidgetSupport.contains("func currentWalkWidgetPetContext()"), "widget/watch should share current pet context resolver")
assertTrue(mapWidgetSupport.contains("func applyRequestedWalkPetContextIfNeeded"), "widget/watch should share requested pet context application")

assertTrue(checkScript.contains("swift scripts/watch_selected_pet_context_ux_unit_check.swift"), "ios_pr_check should run watch selected pet context unit check")

print("PASS: watch selected pet context UX unit checks")
