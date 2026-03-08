import Foundation

struct Check {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ path: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}

let doc = try load("docs/map-quest-overlay-priority-matrix-v1.md")
let models = try load("dogArea/Source/Domain/Quest/Models/QuestMapOverlayPriorityModels.swift")
let service = try load("dogArea/Source/Domain/Quest/Services/QuestMapOverlayPriorityService.swift")
let readme = try load("README.md")
let prCheck = try load("scripts/ios_pr_check.sh")

Check.require(doc.contains("critical / operational / progress"), "doc must define three overlay tiers")
Check.require(doc.contains("top overlay slot"), "doc must define top overlay slot role")
Check.require(doc.contains("toast slot"), "doc must define toast slot role")
Check.require(doc.contains("120초"), "doc must define HUD suppress duration")
Check.require(doc.contains("1.5초"), "doc must define stable window")
Check.require(doc.contains("0.35초"), "doc must define coalescing window")
Check.require(doc.contains("recoveryIssue") && doc.contains("syncOutbox") && doc.contains("watchStatus"), "doc must map current banner kinds")
Check.require(doc.contains("#465") && doc.contains("#467"), "doc must reference prerequisite issues")

Check.require(models.contains("enum QuestMapOverlayFeedbackTier"), "models must define overlay tiers")
Check.require(models.contains("enum QuestMapTopOverlaySlotMode"), "models must define top slot modes")
Check.require(models.contains("enum QuestMapOverlayHUDDisplayState"), "models must define HUD display states")
Check.require(models.contains("enum QuestMapOverlayToastDisplayState"), "models must define toast display states")
Check.require(models.contains("struct QuestMapOverlayRuntimeContext"), "models must define runtime context")
Check.require(models.contains("struct QuestMapOverlayRuntimeResolution"), "models must define runtime resolution")
Check.require(models.contains("struct QuestMapOverlayStateMatrixRow"), "models must define state matrix rows")
Check.require(models.contains("struct QuestMapOverlayPrioritySnapshot"), "models must define snapshot")

Check.require(service.contains("protocol QuestMapOverlayPriorityResolving"), "service must define protocol")
Check.require(service.contains("func makePolicySnapshot() -> QuestMapOverlayPrioritySnapshot"), "service must build snapshot")
Check.require(service.contains("func resolve(context: QuestMapOverlayRuntimeContext) -> QuestMapOverlayRuntimeResolution"), "service must expose runtime resolution")
Check.require(service.contains("shouldHideHUDForDensity"), "service must include density guard")
Check.require(service.contains("resolvedToastState"), "service must include toast slot rule")
Check.require(service.contains("stateMatrix()"), "service must define state matrix")

Check.require(readme.contains("지도 상단 overlay 우선순위 매트릭스 v1"), "README must index overlay priority doc")
Check.require(prCheck.contains("swift scripts/map_quest_overlay_priority_unit_check.swift"), "ios_pr_check must run overlay priority unit check")

print("PASS: map quest overlay priority checks")
