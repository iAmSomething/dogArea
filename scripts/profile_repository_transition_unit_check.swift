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

let repository = load("dogArea/Source/ProfileRepository.swift")
let signingViewModel = load("dogArea/Views/SigningView/SigningViewModel.swift")
let settingViewModel = load("dogArea/Views/ProfileSettingView/SettingViewModel.swift")
let transitionDoc = load("docs/data-layer-transition-v1.md")

assertTrue(repository.contains("protocol ProfileRepository"), "profile repository protocol must exist")
assertTrue(repository.contains("final class DefaultProfileRepository"), "default profile repository must exist")
assertTrue(repository.contains("syncCoordinator.enqueueSnapshot"), "repository must own sync enqueue responsibility")
assertTrue(repository.contains("syncCoordinator.flushIfNeeded"), "repository must own sync flush responsibility")

assertTrue(signingViewModel.contains("private let profileRepository"), "signing view model should inject profile repository")
assertTrue(signingViewModel.contains("DefaultProfileRepository.shared"), "signing view model should default to repository shared impl")
assertTrue(signingViewModel.contains("profileRepository.save"), "signing flow should save through repository")

assertTrue(settingViewModel.contains("private let profileRepository"), "setting view model should inject profile repository")
assertTrue(settingViewModel.contains("profileRepository.fetchUserInfo"), "setting flow should read through repository")
assertTrue(settingViewModel.contains("profileRepository.save"), "setting flow should save through repository")

assertTrue(transitionDoc.contains("#117"), "transition doc must link issue #117")
assertTrue(transitionDoc.contains("ProfileRepository"), "transition doc should mention profile repository adoption")

print("PASS: profile repository transition unit checks")
