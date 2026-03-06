import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let profileSyncOutbox = load("dogArea/Source/ProfileSyncOutboxStore.swift")
let petManagementService = load("dogArea/Source/Domain/Profile/Services/SettingsPetManagementService.swift")
let profileDoc = load("docs/profile-edit-flow-v1.md")

assertTrue(profileSyncOutbox.contains("\"is_active\": pet.isActive ? \"true\" : \"false\""), "profile sync outbox should forward pet activation state")
assertTrue(petManagementService.contains("cannotDeactivateLastActivePet"), "pet management service should protect last active pet")
assertTrue(petManagementService.contains("uploadPetProfileImage"), "pet management service should upload new pet image when present")
assertTrue(petManagementService.contains("func updatePet("), "pet management service should support existing pet editing")
assertTrue(profileDoc.contains("selectedPetId`는 항상 활성 반려견 기준으로 보정"), "profile edit spec should define selected pet fallback policy")
assertTrue(profileDoc.contains("기존 반려견 편집"), "profile edit spec should include existing pet edit flow")

print("PASS: settings pet management unit checks")
