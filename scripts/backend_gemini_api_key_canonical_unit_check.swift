import Foundation

/// 조건이 거짓이면 stderr에 실패 메시지를 출력하고 프로세스를 종료합니다.
/// - Parameters:
///   - condition: 검증할 조건식입니다.
///   - message: 검증 실패 시 출력할 설명입니다.
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
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

/// 저장소 전체를 순회해 특정 문자열이 남아 있는지 확인합니다.
/// - Parameter needle: 검색할 평문 문자열입니다.
/// - Returns: 일치하는 파일/라인 목록입니다.
func grep(_ needle: String) -> [String] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["rg", "-n", needle, "."]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return []
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(decoding: data, as: UTF8.self)
    return output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
}

let function = load("supabase/functions/caricature/index.ts")
let functionReadme = load("supabase/functions/caricature/README.md")
let secretRunbook = load("docs/backend-edge-secret-inventory-rotation-runbook-v1.md")
let legacySunset = load("docs/backend-legacy-fallback-compat-sunset-plan-v1.md")
let canonicalDoc = load("docs/backend-gemini-api-key-canonical-v1.md")
let readme = load("README.md")
let backendCheck = load("scripts/backend_pr_check.sh")
let iosCheck = load("scripts/ios_pr_check.sh")
let caricatureUnitCheck = load("scripts/caricature_proxy_unit_check.swift")
let legacyAlias = "GEMINI" + "_KEY"
let legacyEnvLookup = "Deno.env.get(\"" + legacyAlias + "\")"

assertTrue(function.contains("Deno.env.get(\"GEMINI_API_KEY\")"), "caricature function should read GEMINI_API_KEY")
assertTrue(!function.contains(legacyEnvLookup), "caricature function should not read the removed Gemini alias")
assertTrue(functionReadme.contains("`GEMINI_API_KEY`"), "caricature README should document GEMINI_API_KEY")
assertTrue(!functionReadme.contains(legacyAlias), "caricature README should not mention the removed Gemini alias")

assertTrue(secretRunbook.contains("canonical Gemini key"), "secret runbook should keep canonical Gemini key guidance")
assertTrue(!secretRunbook.contains(legacyAlias), "secret runbook should not keep legacy alias inventory")
assertTrue(!legacySunset.contains(legacyAlias), "legacy fallback sunset doc should not list removed Gemini alias")

assertTrue(canonicalDoc.contains("#479"), "canonicalization doc should reference issue #479")
assertTrue(canonicalDoc.contains("`GEMINI_API_KEY`"), "canonicalization doc should define GEMINI_API_KEY")
assertTrue(canonicalDoc.contains("legacy Gemini alias"), "canonicalization doc should describe removed alias verification")

assertTrue(caricatureUnitCheck.contains("GEMINI_API_KEY"), "caricature unit check should verify GEMINI_API_KEY")
assertTrue(!caricatureUnitCheck.contains("GEMINI_API_KEY\") ?? " + legacyEnvLookup), "caricature unit check should not allow the legacy alias")

assertTrue(readme.contains("docs/backend-gemini-api-key-canonical-v1.md"), "README should index the canonicalization doc")
assertTrue(backendCheck.contains("backend_gemini_api_key_canonical_unit_check.swift"), "backend_pr_check should run the canonicalization check")
assertTrue(iosCheck.contains("backend_gemini_api_key_canonical_unit_check.swift"), "ios_pr_check should run the canonicalization check")

let legacyMatches = grep(legacyAlias)
assertTrue(legacyMatches.isEmpty, "repository should not contain removed Gemini alias references")

print("PASS: backend gemini api key canonicalization unit checks")
