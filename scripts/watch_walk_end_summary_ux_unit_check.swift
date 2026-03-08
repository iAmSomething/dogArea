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
let doc = read(root + "/docs/watch-walk-end-summary-ux-v1.md")
let contentView = read(root + "/dogAreaWatch Watch App/ContentView.swift")
let watchViewModel = read(root + "/dogAreaWatch Watch App/ContentsViewModel.swift")
let endSheet = read(root + "/dogAreaWatch Watch App/WatchWalkEndDecisionSheetView.swift")
let summaryState = read(root + "/dogAreaWatch Watch App/WatchWalkCompletionSummaryState.swift")
let summarySheet = read(root + "/dogAreaWatch Watch App/WatchWalkCompletionSummarySheetView.swift")
let summaryGrid = read(root + "/dogAreaWatch Watch App/WatchWalkSummaryMetricGridView.swift")
let iphoneMapModel = read(root + "/dogArea/Views/MapView/MapViewModel.swift")
let iphoneWatchSupport = read(root + "/dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WatchConnectivitySupport.swift")
let prCheck = read(root + "/scripts/ios_pr_check.sh")

assertTrue(readme.contains("watch-walk-end-summary-ux-v1.md"), "README should index watch walk end summary doc")
assertTrue(doc.contains("#523"), "doc should mention issue #523")
assertTrue(doc.contains("저장하고 종료 / 계속 걷기 / 기록 폐기"), "doc should define three-action end flow")
assertTrue(doc.contains("watch_completion_summary"), "doc should define watch completion summary payload")
assertTrue(doc.contains("오프라인"), "doc should define offline fallback")

assertTrue(contentView.contains("WatchWalkEndDecisionSheetView"), "watch content should present end decision sheet")
assertTrue(contentView.contains("WatchWalkCompletionSummarySheetView"), "watch content should present completion summary sheet")
assertTrue(contentView.contains("isWalkEndDecisionPresented"), "watch content should manage end decision presentation state")

assertTrue(watchViewModel.contains("case discardWalk = \"discardWalk\""), "watch action type should include discardWalk")
assertTrue(watchViewModel.contains("enum WatchWalkEndDecision"), "watch view model should define end decision enum")
assertTrue(watchViewModel.contains("func handleWalkEndDecision"), "watch view model should handle end decision actions")
assertTrue(watchViewModel.contains("walkCompletionSummary"), "watch view model should publish completion summary")
assertTrue(watchViewModel.contains("presentWalkCompletionSummaryIfNeeded"), "watch view model should gate summary presentation")
assertTrue(watchViewModel.contains("presentedCompletionSummaryActionIdStorageKey"), "watch view model should persist presented summary action id")

assertTrue(endSheet.contains("저장하고 종료"), "end decision sheet should expose save action")
assertTrue(endSheet.contains("계속 걷기"), "end decision sheet should expose continue action")
assertTrue(endSheet.contains("기록 폐기"), "end decision sheet should expose discard action")
assertTrue(summaryState.contains("struct WatchWalkCompletionSummaryState"), "watch target should define completion summary state")
assertTrue(summaryState.contains("watch_completion_summary"), "summary state should parse watch completion payload")
assertTrue(summarySheet.contains("summary.followUpNote"), "completion summary sheet should render follow-up note")
assertTrue(summaryGrid.contains("포인트"), "summary metric grid should render point count")
assertTrue(summaryGrid.contains("반려견"), "summary metric grid should render pet name")

assertTrue(iphoneMapModel.contains("case discardWalk"), "iphone map model should parse discard watch action")
assertTrue(iphoneMapModel.contains("enum WatchCompletionSummaryResult"), "iphone map model should define completion summary result")
assertTrue(iphoneWatchSupport.contains("point_count"), "iphone watch context should include point count")
assertTrue(iphoneWatchSupport.contains("watch_completion_summary"), "iphone watch context should include completion summary payload")
assertTrue(iphoneWatchSupport.contains("captureWatchCompletionSummary"), "iphone watch support should capture completion summary before ending")
assertTrue(iphoneWatchSupport.contains("self.discardCurrentWalk()"), "iphone watch support should route discard action to existing discard flow")

assertTrue(prCheck.contains("swift scripts/watch_walk_end_summary_ux_unit_check.swift"), "ios_pr_check should run watch walk end summary unit check")

print("PASS: watch walk end summary UX unit checks")
