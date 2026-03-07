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

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로 파일을 UTF-8 문자열로 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 전체 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let function = load("supabase/functions/upload-profile-image/index.ts")
let helper = load("supabase/functions/_shared/storage_upload.ts")
let readme = load("supabase/functions/upload-profile-image/README.md")
let policyDoc = load("docs/backend-upload-profile-image-owner-binding-policy-v1.md")
let authSmoke = load("scripts/auth_member_401_smoke_check.sh")

assertTrue(function.contains("ensureAuthenticatedUserMatch"), "upload-profile-image should bind member ownerId to authenticated user")
assertTrue(function.contains("ANON_ONBOARDING_OWNER_PREFIX"), "upload-profile-image should define anon onboarding owner prefix")
assertTrue(function.contains("ANON_OWNER_NAMESPACE_REQUIRED"), "upload-profile-image should reject anon uploads outside onboarding namespace")
assertTrue(function.contains("resolveAnonOnboardingProfileImageObjectPath"), "upload-profile-image should route anon uploads to isolated storage path")

assertTrue(helper.contains("resolveAnonOnboardingProfileImageObjectPath"), "shared storage helper should expose anon onboarding path resolver")

assertTrue(readme.contains("auth.user.id"), "upload-profile-image README should document member owner binding")
assertTrue(readme.contains("anon-onboarding-*"), "upload-profile-image README should document anon namespace restriction")
assertTrue(readme.contains("ANON_OWNER_NAMESPACE_REQUIRED"), "upload-profile-image README should document anon namespace error")

assertTrue(policyDoc.contains("member bearer"), "owner binding policy doc should describe member bearer rules")
assertTrue(policyDoc.contains("anon bearer"), "owner binding policy doc should describe anon bearer rules")
assertTrue(policyDoc.contains("member_mismatch=403"), "owner binding policy doc should document mismatch smoke expectation")

assertTrue(authSmoke.contains("anon-onboarding-auth-smoke-"), "auth smoke should exercise anon onboarding namespace uploads")
assertTrue(authSmoke.contains("member_mismatch"), "auth smoke should assert member owner mismatch behavior")

print("PASS: upload-profile-image owner binding policy unit checks")
