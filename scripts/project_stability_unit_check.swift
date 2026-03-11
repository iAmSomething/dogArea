import Foundation

/// Validates that a project stability invariant holds.
/// - Parameters:
///   - condition: Condition that must remain true.
///   - message: Failure message printed when the invariant breaks.
@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// Loads a repository-relative UTF-8 text file.
/// - Parameter relativePath: Repository-relative file path to read.
/// - Returns: Decoded file contents.
func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let pbxproj = load("dogArea.xcodeproj/project.pbxproj")
let workflow = load(".github/workflows/ios-pr-check.yml")
let script = load("scripts/ios_pr_check.sh")
let doc = load("docs/project-settings-dependency-stability-v1.md")
let readme = load("README.md")

assertTrue(pbxproj.contains("IPHONEOS_DEPLOYMENT_TARGET = 18.0;"), "project should pin iOS deployment target 18.0")
assertTrue(pbxproj.contains("WATCHOS_DEPLOYMENT_TARGET = 10.2;"), "project should pin watchOS deployment target 10.2")
assertTrue(pbxproj.contains("SWIFT_VERSION = 5.0;"), "project should pin Swift version 5.0")
assertTrue(pbxproj.contains("path = dogAreaSplash.json;"), "project should use repo-relative splash animation path")
assertTrue(!pbxproj.contains("path = ../../../../dogAreaSplash.json;"), "project should avoid unstable relative splash path")

assertTrue(workflow.contains("name: ios-full-check"), "workflow should be named ios-full-check")
assertTrue(workflow.contains("push:"), "workflow should run on push")
assertTrue(!workflow.contains("pull_request:"), "full check workflow should no longer run on pull_request")
assertTrue(workflow.contains("branches:"), "workflow should specify target branches")
assertTrue(workflow.contains("- main"), "workflow should target main branch")
assertTrue(workflow.contains("bash scripts/ios_pr_check.sh"), "workflow should run shared PR check script")

assertTrue(script.contains("swift scripts/project_stability_unit_check.swift"), "shared script should include stability unit check")
assertTrue(script.contains("-scheme dogArea"), "shared script should build iOS scheme")
assertTrue(script.contains("-scheme \"dogAreaWatch Watch App\""), "shared script should build watchOS scheme")

assertTrue(doc.contains("## 2. 기준 툴체인/타깃"), "stability doc should include toolchain baseline")
assertTrue(doc.contains("## 4. 로컬/CI 공통 체크 명령"), "stability doc should include unified commands")
assertTrue(doc.contains("## 5. CI 역할 분리 기준"), "stability doc should include CI role split criteria")

assertTrue(readme.contains("docs/project-settings-dependency-stability-v1.md"), "README should reference project stability doc")
assertTrue(readme.contains("bash scripts/ios_pr_check.sh"), "README should expose unified local check command")

print("PASS: project stability unit checks")
