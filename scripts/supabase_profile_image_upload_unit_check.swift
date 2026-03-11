import Foundation

/// 조건이 거짓이면 stderr에 실패 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 조건이 거짓일 때 출력할 설명입니다.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

/// 여러 파일을 읽어 하나의 문자열로 합칩니다.
/// - Parameter relativePaths: 저장소 루트 기준 상대 경로 배열입니다.
/// - Returns: 각 파일 본문을 줄바꿈으로 이어붙인 문자열입니다.
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
let sharedHelper = load("supabase/functions/_shared/storage_upload.ts")
let allowlistSnippet = infra.range(of: "private static let edgeFunctionAnonRetryAllowlist").map {
    String(infra[$0.lowerBound...].prefix(180))
} ?? ""

assertTrue(infra.contains("SupabaseProfileImageRepository"), "infra should define SupabaseProfileImageRepository")
assertTrue(infra.contains("upload-profile-image"), "infra should call upload-profile-image edge function")
assertTrue(!allowlistSnippet.contains("\"upload-profile-image\""), "http client should not route upload-profile-image through anon-first allowlist")
assertTrue(infra.contains("localizedUploadFailureMessage(statusCode: statusCode, imageKind: imageKind)"), "profile image repository should map upload status codes to user-facing failure copy")
assertTrue(signingVM.contains("SupabaseProfileImageRepository.shared"), "signup should default to supabase image repository")

assertTrue(function.contains("storage"), "edge function should call storage")
assertTrue(function.contains("uploadPublicStorageObject"), "edge function should call shared public storage upload helper")
assertTrue(function.contains("resolveProfileImageObjectPath"), "edge function should use shared profile image path helper")
assertTrue(function.contains("resolveAnonOnboardingProfileImageObjectPath"), "edge function should separate anon onboarding profile path helper")
assertTrue(function.contains("MAX_IMAGE_BYTES"), "edge function should guard max upload size")
assertTrue(function.contains("storageResult.code"), "edge function should forward canonical helper storage error codes")
assertTrue(function.contains("ensureAuthenticatedUserMatch"), "edge function should bind member upload ownerId to authenticated user")
assertTrue(function.contains("ANON_OWNER_NAMESPACE_REQUIRED"), "edge function should reject anon uploads outside the onboarding namespace")
assertTrue(sharedHelper.contains("resolveProfileImageObjectPath"), "shared helper should define profile image path resolver")
assertTrue(sharedHelper.contains("resolveAnonOnboardingProfileImageObjectPath"), "shared helper should define anon onboarding profile image path resolver")
assertTrue(sharedHelper.contains("uploadPublicStorageObject"), "shared helper should define upload helper")
assertTrue(sharedHelper.contains("\"STORAGE_UPLOAD_FAILED\""), "shared helper should define canonical storage upload failure code")
assertTrue(sharedHelper.contains("\"PUBLIC_URL_FAILED\""), "shared helper should define public url failure code")
assertTrue(readme.contains("profiles"), "edge function README should document profiles bucket")
assertTrue(readme.contains("anon-onboarding-*"), "edge function README should document anon onboarding namespace policy")
assertTrue(readme.contains("UNAUTHORIZED_USER_MISMATCH"), "edge function README should document member owner binding mismatch error")

print("PASS: supabase profile image upload unit checks")
