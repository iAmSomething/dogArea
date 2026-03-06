import Foundation

struct Check {
    static var failed = false

    static func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            print("[PASS] \(message)")
        } else {
            failed = true
            print("[FAIL] \(message)")
        }
    }
}

func read(_ path: String) -> String {
    (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
}

func readMany(_ paths: [String]) -> String {
    paths.map(read).joined(separator: "\n")
}

let mapViewModel = readMany([
    "dogArea/Views/MapView/MapViewModel.swift",
    "dogArea/Views/MapView/MapViewModelSupport/MapViewModel+WatchConnectivitySupport.swift"
])
let watchVM = read("dogAreaWatch Watch App/ContentsViewModel.swift")
let watchView = read("dogAreaWatch Watch App/ContentView.swift")
let docs = read("docs/watch-connectivity-reliability-v1.md")

Check.assertTrue(mapViewModel.contains("static let version = \"watch.remote.v1\""), "iphone side should define watch contract version")
Check.assertTrue(mapViewModel.contains("WatchActionEnvelope"), "iphone side should parse watch envelope")
Check.assertTrue(mapViewModel.contains("payload\"] as? [String: Any]"), "iphone parser should support nested payload contract")
Check.assertTrue(mapViewModel.contains("didReceiveMessage message: [String : Any],"), "iphone delegate should support reply handler message path")
Check.assertTrue(mapViewModel.contains("type\": WatchContract.ackType"), "iphone should return watch ack type")
Check.assertTrue(mapViewModel.contains("last_action_id_applied"), "iphone should send last applied action id in context")

Check.assertTrue(watchVM.contains("watch.remote.v1"), "watch side should pin contract version")
Check.assertTrue(watchVM.contains("\"type\": type"), "watch side should include type in envelope")
Check.assertTrue(watchVM.contains("session.sendMessage(action.envelope"), "watch should send immediate message with envelope")
Check.assertTrue(watchVM.contains("session.transferUserInfo($0.envelope)"), "watch should queue and resend via transferUserInfo")
Check.assertTrue(watchVM.contains("lastAckStatus"), "watch view model should expose ack status")
Check.assertTrue(watchVM.contains("pendingActionCount"), "watch view model should expose pending queue size")

Check.assertTrue(watchView.contains("큐 \\(viewModel.pendingActionCount)건"), "watch UI should render pending queue count")
Check.assertTrue(watchView.contains("ACK"), "watch UI should show ack state")

Check.assertTrue(docs.contains("watch.remote.v1"), "docs should describe contract version")
Check.assertTrue(docs.contains("watch_ack"), "docs should describe ack contract")
Check.assertTrue(docs.contains("transferUserInfo"), "docs should define reconnect queue behavior")

if Check.failed {
    exit(1)
}

print("All watch remote contract checks passed.")
