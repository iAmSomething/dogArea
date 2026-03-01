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
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let signInView = load("dogArea/Views/SigningView/SignInView.swift")
let signingViewModel = load("dogArea/Views/SigningView/SigningViewModel.swift")
let settingViewModel = load("dogArea/Views/ProfileSettingView/SettingViewModel.swift")
let infra = load("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")

assertTrue(!signInView.contains("import FirebaseAuth"), "SignInView should not import FirebaseAuth directly")
assertTrue(!signingViewModel.contains("import FirebaseStorage"), "SigningViewModel should not import FirebaseStorage directly")
assertTrue(!settingViewModel.contains("import FirebaseStorage"), "SettingViewModel should not import FirebaseStorage directly")

assertTrue(signInView.contains("AppleCredentialAuthServiceProtocol"), "SignInView should depend on auth service protocol")
assertTrue(signingViewModel.contains("ProfileImageRepository"), "SigningViewModel should depend on image repository protocol")
assertTrue(infra.contains("final class FirebaseAppleCredentialAuthService"), "infrastructure should provide Firebase auth service adapter")
assertTrue(infra.contains("final class FirebaseProfileImageRepository"), "infrastructure should provide Firebase image repository adapter")

print("PASS: presentation firebase boundary unit checks")
