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

let doc = try load("docs/map-quest-hud-minimum-info-set-v1.md")
let model = try load("dogArea/Source/Domain/Quest/Models/QuestMapHUDInfoSetModels.swift")
let service = try load("dogArea/Source/Domain/Quest/Services/QuestMapHUDInfoSetPolicyService.swift")
let readme = try load("README.md")
let prCheck = try load("scripts/ios_pr_check.sh")

Check.require(doc.contains("2줄 + 상태 배지 1개"), "doc must define collapsed density rule")
Check.require(doc.contains("full-width progress bar"), "doc must define progress bar rule")
Check.require(doc.contains("대표 1개 + 추가 n개"), "doc must define multi mission summary rule")
Check.require(doc.contains("진행 중인 퀘스트 없음"), "doc must define empty state copy")
Check.require(doc.contains("거의 완료"), "doc must define near completion badge")
Check.require(doc.contains("보상 가능"), "doc must define claimable badge")
Check.require(doc.contains("16자"), "doc must define title limit")
Check.require(doc.contains("22자"), "doc must define summary limit")
Check.require(doc.contains("#468"), "doc must reference runtime follow-up issue")

Check.require(model.contains("enum QuestMapHUDStateVariant"), "model must define HUD state variants")
Check.require(model.contains("enum QuestMapHUDCollapsedLine"), "model must define collapsed lines")
Check.require(model.contains("enum QuestMapHUDExpandedBlock"), "model must define expanded blocks")
Check.require(model.contains("enum QuestMapHUDNumberExpressionRule"), "model must define number expression rules")
Check.require(model.contains("struct QuestMapHUDCollapsedInfoSet"), "model must define collapsed info set")
Check.require(model.contains("struct QuestMapHUDExpandedInfoSet"), "model must define expanded info set")
Check.require(model.contains("struct QuestMapHUDWireExample"), "model must define wire example")
Check.require(model.contains("struct QuestMapHUDInfoSetPolicySnapshot"), "model must define info set snapshot")

Check.require(service.contains("protocol QuestMapHUDInfoSetPolicyResolving"), "service must expose protocol")
Check.require(service.contains("func makePolicySnapshot() -> QuestMapHUDInfoSetPolicySnapshot"), "service must build snapshot")
Check.require(service.contains("func collapsedInfoSet(for state: QuestMapHUDStateVariant) -> QuestMapHUDCollapsedInfoSet"), "service must provide collapsed info set")
Check.require(service.contains("func expandedInfoSet(for state: QuestMapHUDStateVariant) -> QuestMapHUDExpandedInfoSet"), "service must provide expanded info set")
Check.require(service.contains("func makeWireExamples() -> [QuestMapHUDWireExample]"), "service must provide wire examples")
Check.require(service.contains("QuestSurfacePolicyService().makePolicySnapshot().automaticTrackingRules"), "service must reuse automatic tracking rules")

Check.require(readme.contains("지도 퀘스트 HUD 최소 정보셋 v1"), "README must index the new doc")
Check.require(prCheck.contains("swift scripts/map_quest_hud_minimum_info_unit_check.swift"), "ios_pr_check must run the new unit check")

print("OK: map quest hud minimum info policy")
