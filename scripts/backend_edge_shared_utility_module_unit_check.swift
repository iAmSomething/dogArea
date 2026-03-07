import Foundation

/// 조건이 거짓이면 stderr에 실패 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 검증 실패 시 출력할 설명입니다.
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

let httpHelper = load("supabase/functions/_shared/http.ts")
let parserHelper = load("supabase/functions/_shared/parsers.ts")
let runtimeHelper = load("supabase/functions/_shared/edge_runtime.ts")
let edgeAuth = load("supabase/functions/_shared/edge_auth.ts")
let requestKeys = load("supabase/functions/_shared/request_keys.ts")
let featureControl = load("supabase/functions/feature-control/index.ts")
let questEngine = load("supabase/functions/quest-engine/index.ts")
let uploadProfile = load("supabase/functions/upload-profile-image/index.ts")
let syncProfile = load("supabase/functions/sync-profile/index.ts")
let rivalLeague = load("supabase/functions/rival-league/index.ts")
let guide = load("docs/backend-edge-shared-utility-module-guide-v1.md")
let readme = load("README.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")

assertTrue(httpHelper.contains("export const json"), "shared http helper should export json")
assertTrue(httpHelper.contains("export const errorJson"), "shared http helper should export errorJson")
assertTrue(httpHelper.contains("export const methodNotAllowed"), "shared http helper should export methodNotAllowed")
assertTrue(httpHelper.contains("export async function parseJsonBody"), "shared http helper should export parseJsonBody")

assertTrue(parserHelper.contains("export const asString"), "shared parser helper should export asString")
assertTrue(parserHelper.contains("export const asRecord"), "shared parser helper should export asRecord")
assertTrue(parserHelper.contains("export const toNumber"), "shared parser helper should export toNumber")
assertTrue(parserHelper.contains("export const toBoolean"), "shared parser helper should export toBoolean")
assertTrue(parserHelper.contains("export const toNullableInt"), "shared parser helper should export toNullableInt")
assertTrue(parserHelper.contains("export const toUUIDOrNull"), "shared parser helper should export toUUIDOrNull")

assertTrue(runtimeHelper.contains("export function requireSupabaseRuntimeEnv"), "shared runtime helper should export requireSupabaseRuntimeEnv")
assertTrue(edgeAuth.contains("resolveEdgeAuthContext"), "shared auth preflight should stay in edge_auth")
assertTrue(requestKeys.contains("resolveCanonicalRequestId"), "shared request metadata helper should still exist")

for file in [featureControl, questEngine, uploadProfile, syncProfile, rivalLeague] {
    assertTrue(file.contains("../_shared/http.ts"), "migrated function should import shared http helper")
    assertTrue(file.contains("../_shared/edge_runtime.ts"), "migrated function should import shared runtime helper")
}

for file in [questEngine, uploadProfile, syncProfile] {
    assertTrue(file.contains("../_shared/parsers.ts"), "parser-heavy function should import shared parser helper")
}

assertTrue(!featureControl.contains("const json ="), "feature-control should no longer define local json helper")
assertTrue(!questEngine.contains("const json ="), "quest-engine should no longer define local json helper")
assertTrue(!uploadProfile.contains("const json ="), "upload-profile-image should no longer define local json helper")
assertTrue(!syncProfile.contains("const json ="), "sync-profile should no longer define local json helper")
assertTrue(!rivalLeague.contains("const json ="), "rival-league should no longer define local json helper")

assertTrue(!questEngine.contains("const asString ="), "quest-engine should use shared string parser")
assertTrue(!uploadProfile.contains("const asString ="), "upload-profile-image should use shared string parser")
assertTrue(!syncProfile.contains("const asString ="), "sync-profile should use shared string parser")
assertTrue(!syncProfile.contains("const toBoolean ="), "sync-profile should use shared boolean parser")
assertTrue(!syncProfile.contains("const toNullableInt ="), "sync-profile should use shared int parser")
assertTrue(!syncProfile.contains("const toUUIDOrNull ="), "sync-profile should use shared uuid parser")

for token in [
    "http.ts",
    "parsers.ts",
    "edge_runtime.ts",
    "edge_auth.ts",
    "request_keys.ts",
    "feature-control",
    "quest-engine",
    "upload-profile-image",
    "sync-profile",
    "rival-league",
    "sync-walk",
    "nearby-presence",
    "caricature"
] {
    assertTrue(guide.contains(token), "shared utility guide should mention \(token)")
}

assertTrue(readme.contains("docs/backend-edge-shared-utility-module-guide-v1.md"), "README should link shared utility guide")
assertTrue(backendCheck.contains("backend_edge_shared_utility_module_unit_check.swift"), "backend_pr_check should run shared utility module check")
assertTrue(iosPRCheck.contains("backend_edge_shared_utility_module_unit_check.swift"), "ios_pr_check should run shared utility module check")

print("PASS: backend edge shared utility module unit checks")
