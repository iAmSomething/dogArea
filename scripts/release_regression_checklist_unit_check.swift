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
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let checklist = load("docs/release-regression-checklist-v1.md")
let report = load("docs/release-regression-report-2026-02-26.md")

assertTrue(checklist.contains("## 3. 빌드 체크"), "checklist must include build check section")
assertTrue(checklist.contains("## 4. 핵심 시나리오 체크"), "checklist must include scenario check section")
assertTrue(checklist.contains("## 5. 마이그레이션 검증 시나리오"), "checklist must include migration section")
assertTrue(checklist.contains("## 6. 결과 기록 템플릿"), "checklist must include result template")
assertTrue(checklist.contains("## 7. 예외 시나리오 게이트 (P0/P1)"), "checklist must include exception gate section")
assertTrue(checklist.contains("P0 FAIL >= 1"), "checklist must include P0 auto blocking rule")

assertTrue(report.contains("## 1. 빌드 체크 결과"), "report must include build results")
assertTrue(report.contains("## 2. 핵심 시나리오 점검 결과"), "report must include scenario results")
assertTrue(report.contains("## 3. 마이그레이션 검증 결과"), "report must include migration results")
assertTrue(report.contains("릴리즈 가능 여부"), "report must include GO/NO-GO decision")

print("PASS: release regression checklist unit checks")
