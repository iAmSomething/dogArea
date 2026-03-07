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

/// 여러 파일을 읽어 하나의 문자열로 합칩니다.
/// - Parameter relativePaths: 저장소 루트 기준 상대 경로 배열입니다.
/// - Returns: 각 파일 본문을 줄바꿈으로 이어붙인 문자열입니다.
func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let doc = load("docs/backend-edge-secret-inventory-rotation-runbook-v1.md")
let readme = load("README.md")
let runbook = load("docs/backend-edge-incident-runbook-v1.md")
let authPolicy = load("docs/backend-edge-auth-policy-v1.md")
let applePlan = load("docs/supabase-auth-apple-plan.md")
let providerRouter = load("docs/image-provider-router-v1.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosPRCheck = load("scripts/ios_pr_check.sh")
let authSmoke = load("scripts/auth_member_401_smoke_check.sh")
let config = load("supabase/config.toml")
let functionSources = loadMany([
    "supabase/functions/sync-walk/index.ts",
    "supabase/functions/sync-profile/index.ts",
    "supabase/functions/rival-league/index.ts",
    "supabase/functions/quest-engine/index.ts",
    "supabase/functions/nearby-presence/index.ts",
    "supabase/functions/feature-control/index.ts",
    "supabase/functions/upload-profile-image/index.ts",
    "supabase/functions/caricature/index.ts"
])

for token in [
    "runtime_config",
    "public_client_credential",
    "edge_runtime_secret",
    "platform_secret",
    "SUPABASE_URL",
    "PROJECT_REF",
    "SUPABASE_ANON_KEY",
    "SUPABASE_SERVICE_ROLE_KEY",
    "OPENAI_API_KEY",
    "GEMINI_API_KEY",
    "GEMINI_KEY",
    "SUPABASE_AUTH_EXTERNAL_APPLE_SECRET",
    "S3_SECRET_KEY"
] {
    assertTrue(doc.contains(token), "secret inventory doc should mention \(token)")
}

assertTrue(doc.contains("`SUPABASE_ANON_KEY`는 **service role secret과 같은 수준의 비밀키가 아닙니다.**"), "doc should distinguish anon key from real secrets")
assertTrue(doc.contains("highest severity"), "doc should define highest severity incident rule for service role key")
assertTrue(doc.contains("ALL_PROVIDERS_FAILED"), "doc should document provider failure mode")
assertTrue(doc.contains("#479"), "doc should reference legacy Gemini key follow-up")

for functionName in [
    "sync-walk",
    "sync-profile",
    "rival-league",
    "quest-engine",
    "nearby-presence",
    "feature-control",
    "upload-profile-image",
    "caricature"
] {
    assertTrue(doc.contains("`\(functionName)`"), "doc should include function mapping for \(functionName)")
}

for snippet in [
    "Deno.env.get(\"SUPABASE_URL\")",
    "Deno.env.get(\"SUPABASE_ANON_KEY\")",
    "Deno.env.get(\"SUPABASE_SERVICE_ROLE_KEY\")",
    "Deno.env.get(\"OPENAI_API_KEY\")",
    "Deno.env.get(\"GEMINI_API_KEY\") ?? Deno.env.get(\"GEMINI_KEY\")"
] {
    assertTrue(functionSources.contains(snippet), "function sources should still include \(snippet)")
}

assertTrue(config.contains("openai_api_key = \"env(OPENAI_API_KEY)\""), "config should reference OPENAI_API_KEY")
assertTrue(config.contains("secret = \"env(SUPABASE_AUTH_EXTERNAL_APPLE_SECRET)\""), "config should reference Apple external auth secret")
assertTrue(config.contains("s3_secret_key = \"env(S3_SECRET_KEY)\""), "config should reference S3 secret")

assertTrue(readme.contains("docs/backend-edge-secret-inventory-rotation-runbook-v1.md"), "README should link secret inventory doc")
assertTrue(runbook.contains("docs/backend-edge-secret-inventory-rotation-runbook-v1.md"), "incident runbook should link secret inventory doc")
assertTrue(authPolicy.contains("docs/backend-edge-secret-inventory-rotation-runbook-v1.md"), "auth policy should link secret inventory doc")
assertTrue(applePlan.contains("service role 키는 앱에서 사용 금지"), "apple auth plan should still contain service role boundary")
assertTrue(providerRouter.contains("OPENAI_API_KEY") && providerRouter.contains("GEMINI_API_KEY"), "provider router doc should still mention provider secrets")
assertTrue(authSmoke.contains("SUPABASE_URL") && authSmoke.contains("SUPABASE_ANON_KEY"), "auth smoke should still document runtime credential usage")

assertTrue(backendCheck.contains("backend_edge_secret_inventory_unit_check.swift"), "backend_pr_check should run secret inventory unit check")
assertTrue(iosPRCheck.contains("backend_edge_secret_inventory_unit_check.swift"), "ios_pr_check should run secret inventory unit check")

print("PASS: backend edge secret inventory unit checks")
