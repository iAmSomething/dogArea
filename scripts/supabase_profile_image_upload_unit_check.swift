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

let infra = loadMany([
    "dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift",
    "dogArea/Source/Infrastructure/Supabase/Services/SupabaseAuthAndAssetServices.swift"
])
let signingVM = load("dogArea/Views/SigningView/SigningViewModel.swift")
let function = load("supabase/functions/upload-profile-image/index.ts")
let readme = load("supabase/functions/upload-profile-image/README.md")

assertTrue(infra.contains("SupabaseProfileImageRepository"), "infra should define SupabaseProfileImageRepository")
assertTrue(infra.contains("upload-profile-image"), "infra should call upload-profile-image edge function")
assertTrue(signingVM.contains("SupabaseProfileImageRepository.shared"), "signup should default to supabase image repository")

assertTrue(function.contains("storage"), "edge function should call storage")
assertTrue(function.contains("from(\"profiles\")"), "edge function should upload into profiles bucket")
assertTrue(function.contains("MAX_IMAGE_BYTES"), "edge function should guard max upload size")
assertTrue(function.contains("upsert: true"), "edge function should upsert existing profile images")
assertTrue(readme.contains("profiles"), "edge function README should document profiles bucket")

print("PASS: supabase profile image upload unit checks")
