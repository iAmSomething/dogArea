import Foundation

@discardableResult
func require(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    return true
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("FAIL: unable to read \(relativePath)\n", stderr)
        exit(1)
    }
    return content
}

let bridge = read("dogArea/Source/WidgetBridge/WalkWidgetBridge.swift")
let intents = read("dogAreaWidgetExtension/WalkControlIntents.swift")
let snapshotStore = read("dogArea/Source/WidgetBridge/WalkWidgetSnapshotStore.swift")
let doc = read("docs/widget-action-bridge-observability-v1.md")
let readme = read("README.md")
let prCheck = read("scripts/ios_pr_check.sh")

require(bridge.contains("enum WalkWidgetBridgeStorageMode"), "bridge should define storage mode taxonomy")
require(bridge.contains("enum WalkWidgetBridgeDiagnostics"), "bridge should define diagnostics logger")
require(bridge.contains("[WidgetAction]"), "bridge diagnostics should use canonical prefix")
require(bridge.contains("setPending success"), "bridge should log successful pending request writes")
require(bridge.contains("pendingRequest loaded"), "bridge should log pending request loads")
require(bridge.contains("discardPending removed"), "bridge should log pending request removals")
require(bridge.contains("standard_fallback"), "bridge should expose standard fallback storage mode")
require(bridge.contains("app_group_suite"), "bridge should expose app group storage mode")

require(intents.contains("intent preparePendingRoute"), "widget intents should log intent entry")
require(intents.contains("intent prepared openURL"), "widget intents should log generated openURL")

require(snapshotStore.contains("walk snapshot store ready"), "snapshot store should log storage mode on init")
require(snapshotStore.contains("walk snapshot save"), "snapshot store should log save events")
require(snapshotStore.contains("walk snapshot decode_failed"), "snapshot store should log decode failures")
require(snapshotStore.contains("walk snapshot reloadTimelines"), "snapshot store should log timeline reloads")

for heading in [
    "# Widget Action Bridge Observability v1",
    "## Canonical prefix",
    "## Required logs",
    "## Storage mode taxonomy",
    "## Guardrail"
] {
    require(doc.contains(heading), "doc should contain heading \(heading)")
}

require(doc.contains("Issues: #617, #731"), "doc should reference widget blocker issues")
require(readme.contains("docs/widget-action-bridge-observability-v1.md"), "README should link widget action observability doc")
require(prCheck.contains("widget_action_bridge_observability_unit_check.swift"), "ios_pr_check should run widget action observability checks")

print("PASS: widget action bridge observability unit checks")
