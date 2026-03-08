import Foundation

/// 조건식을 검증하고 실패 시 오류 메시지를 출력한 뒤 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건입니다.
///   - message: 실패 시 출력할 메시지입니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 지정한 상대 경로의 UTF-8 텍스트 파일 내용을 읽어 문자열로 반환합니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일의 UTF-8 문자열 본문입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let policy = load("docs/quest-surface-policy-v1.md")
let model = load("dogArea/Source/Domain/Quest/Models/QuestSurfacePolicyModels.swift")
let service = load("dogArea/Source/Domain/Quest/Services/QuestSurfacePolicyService.swift")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(policy.contains("source of truth"), "Policy should define surface source of truth")
assertTrue(policy.contains("walk_duration"), "Policy should include walk_duration automatic tracking rule")
assertTrue(policy.contains("walk_distance"), "Policy should include walk_distance automatic tracking rule")
assertTrue(policy.contains("new_tile"), "Policy should include new tile automatic tracking rule")
assertTrue(policy.contains("recordCleanup"), "Policy should keep record cleanup as home-only mission")
assertTrue(policy.contains("보상 가능"), "Policy should define claimable-only map feedback")
assertTrue(policy.contains("즉시 수령"), "Policy should explicitly mention immediate claim policy")
assertTrue(policy.contains("#465"), "Policy should hand off to issue #465")
assertTrue(policy.contains("#467"), "Policy should hand off to issue #467")
assertTrue(policy.contains("#468"), "Policy should hand off to issue #468")

assertTrue(model.contains("enum QuestSurfaceVisibilityBucket"), "Model should define surface visibility bucket")
assertTrue(model.contains("enum QuestSurfaceSourceOfTruth"), "Model should define source of truth enum")
assertTrue(model.contains("struct QuestMapMissionCandidate"), "Model should define map mission candidate")
assertTrue(model.contains("struct QuestSurfacePolicySnapshot"), "Model should define policy snapshot")

assertTrue(service.contains("protocol QuestSurfacePolicyResolving"), "Service should expose policy protocol")
assertTrue(service.contains("func makePolicySnapshot() -> QuestSurfacePolicySnapshot"), "Service should build policy snapshot")
assertTrue(service.contains("func selectPrimaryMapCandidate(from candidates: [QuestMapMissionCandidate])"), "Service should define representative mission selection")
assertTrue(service.contains("candidate.isClaimable"), "Representative mission selection should prioritize claimable state")
assertTrue(service.contains("IndoorMissionCategory.allCases"), "Service should classify current indoor mission categories as home-only")

assertTrue(readme.contains("docs/quest-surface-policy-v1.md"), "README should index quest surface policy doc")
assertTrue(prCheck.contains("swift scripts/quest_surface_policy_unit_check.swift"), "ios_pr_check should run quest surface policy gate")

print("PASS: quest surface policy unit checks")
