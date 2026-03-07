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

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let signInView = loadMany([
    "dogArea/Views/SigningView/SignInView.swift",
    "dogArea/Views/SigningView/Components/AuthUserInfo.swift",
    "dogArea/Views/SigningView/Components/EmailSignUpSheetView.swift"
])
let signingViewModel = load("dogArea/Views/SigningView/SigningViewModel.swift")
let settingViewModel = load("dogArea/Views/ProfileSettingView/SettingViewModel.swift")
let infra = loadMany([
    "dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift",
    "dogArea/Source/Infrastructure/Supabase/Services/SupabaseAuthAndAssetServices.swift"
])
let app = load("dogArea/dogAreaApp.swift")
let project = load("dogArea.xcodeproj/project.pbxproj")

assertTrue(!signInView.contains("import FirebaseAuth"), "SignInView should not import FirebaseAuth directly")
assertTrue(!signingViewModel.contains("import FirebaseStorage"), "SigningViewModel should not import FirebaseStorage directly")
assertTrue(!settingViewModel.contains("import FirebaseStorage"), "SettingViewModel should not import FirebaseStorage directly")
assertTrue(!app.contains("import Firebase"), "App entry should not import Firebase runtime modules")
assertTrue(!infra.contains("import Firebase"), "Supabase infrastructure should not import Firebase runtime modules")
assertTrue(!project.contains("firebase-ios-sdk"), "Xcode project should not include firebase-ios-sdk package")
assertTrue(!project.contains("GoogleService-Info.plist in Resources"), "GoogleService-Info.plist should not be in app runtime resources")

assertTrue(signInView.contains("AppleCredentialAuthServiceProtocol"), "SignInView should depend on auth service protocol")
assertTrue(signingViewModel.contains("ProfileImageRepository"), "SigningViewModel should depend on image repository protocol")
assertTrue(infra.contains("final class DeviceAppleCredentialAuthService"), "infrastructure should provide device-level auth adapter")
assertTrue(infra.contains("final class SupabaseProfileImageRepository"), "infrastructure should provide supabase image repository adapter")
assertTrue(infra.contains(".function(name: \"upload-profile-image\")"), "image upload should call supabase upload-profile-image function")

print("PASS: presentation firebase boundary unit checks")
