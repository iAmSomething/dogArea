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

let helper = load("supabase/functions/_shared/storage_upload.ts")
let uploadProfileImage = load("supabase/functions/upload-profile-image/index.ts")
let caricature = load("supabase/functions/caricature/index.ts")
let uploadProfileReadme = load("supabase/functions/upload-profile-image/README.md")
let caricatureReadme = load("supabase/functions/caricature/README.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(helper.contains("uploadPublicStorageObject"), "shared storage helper should expose uploadPublicStorageObject")
assertTrue(helper.contains("resolveProfileImageObjectPath"), "shared storage helper should expose profile image path resolver")
assertTrue(helper.contains("resolveCaricatureObjectPath"), "shared storage helper should expose caricature path resolver")
assertTrue(helper.contains("\"STORAGE_UPLOAD_FAILED\""), "shared storage helper should use canonical STORAGE_UPLOAD_FAILED code")
assertTrue(helper.contains("\"PUBLIC_URL_FAILED\""), "shared storage helper should use canonical PUBLIC_URL_FAILED code")

assertTrue(uploadProfileImage.contains("../_shared/storage_upload.ts"), "upload-profile-image should import shared storage helper")
assertTrue(uploadProfileImage.contains("resolveProfileImageObjectPath"), "upload-profile-image should use shared profile path resolver")
assertTrue(uploadProfileImage.contains("uploadPublicStorageObject"), "upload-profile-image should use shared storage upload helper")
assertTrue(uploadProfileImage.contains("storageResult.code"), "upload-profile-image should forward canonical helper storage error codes")
assertTrue(!uploadProfileImage.contains(".from(\"profiles\")\n    .upload"), "upload-profile-image should not inline profiles upload path anymore")

assertTrue(caricature.contains("../_shared/storage_upload.ts"), "caricature should import shared storage helper")
assertTrue(caricature.contains("resolveCaricatureObjectPath"), "caricature should use shared caricature path resolver")
assertTrue(caricature.contains("uploadPublicStorageObject"), "caricature should use shared storage upload helper")
assertTrue(caricature.contains("PUBLIC_URL_FAILED"), "caricature should now handle public url failure")
assertTrue(!caricature.contains("storage.from(\"caricatures\").upload"), "caricature should not inline caricatures upload path anymore")

assertTrue(uploadProfileReadme.contains("STORAGE_UPLOAD_FAILED"), "upload-profile README should document canonical storage upload code")
assertTrue(uploadProfileReadme.contains("PUBLIC_URL_FAILED"), "upload-profile README should document public url failure code")
assertTrue(caricatureReadme.contains("PUBLIC_URL_FAILED"), "caricature README should document public url failure code")

assertTrue(backendCheck.contains("backend_storage_upload_layer_unit_check.swift"), "backend_pr_check should run shared storage upload layer check")
assertTrue(iosPRCheck.contains("backend_storage_upload_layer_unit_check.swift"), "ios_pr_check should run shared storage upload layer check")

print("PASS: backend shared storage upload layer unit checks")
