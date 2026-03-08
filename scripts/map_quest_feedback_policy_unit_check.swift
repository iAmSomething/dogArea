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
let doc = try String(contentsOf: root.appendingPathComponent("docs/map-quest-feedback-hud-v1.md"), encoding: .utf8)
let models = try String(contentsOf: root.appendingPathComponent("dogArea/Source/Domain/Quest/Models/QuestMapFeedbackPolicyModels.swift"), encoding: .utf8)
let service = try String(contentsOf: root.appendingPathComponent("dogArea/Source/Domain/Quest/Services/QuestMapFeedbackPolicyService.swift"), encoding: .utf8)
let readme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)
let prCheck = try String(contentsOf: root.appendingPathComponent("scripts/ios_pr_check.sh"), encoding: .utf8)

Check.require(doc.contains("HUD + milestone toast + expandable checklist"), "doc must define three-layer feedback model")
Check.require(doc.contains("critical banner"), "doc must define critical banner priority")
Check.require(doc.contains("보상 가능"), "doc must define claimable copy policy")
Check.require(doc.contains("recordCleanup"), "doc must list home-only categories")
Check.require(doc.contains("#467") && doc.contains("#468"), "doc must link follow-up issues")

Check.require(models.contains("enum QuestMapFeedbackLayer"), "models must define feedback layers")
Check.require(models.contains("enum QuestMapMilestoneTrigger"), "models must define milestone triggers")
Check.require(models.contains("enum QuestMapFeedbackCollapsedState"), "models must define collapsed states")
Check.require(models.contains("struct QuestMapChecklistSection"), "models must define checklist sections")
Check.require(models.contains("struct QuestMapFeedbackPolicySnapshot"), "models must define policy snapshot")

Check.require(service.contains("protocol QuestMapFeedbackPolicyResolving"), "service must define protocol")
Check.require(service.contains("func makePolicySnapshot()"), "service must build policy snapshot")
Check.require(service.contains("func collapsedState("), "service must define collapsed state logic")
Check.require(service.contains("func makeChecklistSections("), "service must define checklist policy")
Check.require(service.contains("milestoneToastPolicies()"), "service must define milestone toast policies")
Check.require(service.contains("QuestSurfacePolicyService().makePolicySnapshot().automaticTrackingRules"), "service must reuse #464 automatic tracking rules")

Check.require(readme.contains("지도 퀘스트 피드백 HUD 정책 v1"), "README must index the doc")
Check.require(prCheck.contains("swift scripts/map_quest_feedback_policy_unit_check.swift"), "ios_pr_check must run the new unit check")

print("PASS: map quest feedback policy unit checks")
