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

let matrix = load("docs/fault-injection-matrix-v1.md")
let runbook = load("docs/fault-injection-runbook-v1.md")
let template = load("docs/fault-injection-result-template-v1.md")
let checklist = load("docs/release-regression-checklist-v1.md")

assertTrue(matrix.contains("FI-P0-001"), "matrix must include FI-P0-001 scenario")
assertTrue(matrix.contains("FI-P0-004"), "matrix must include token expiry scenario")
assertTrue(matrix.contains("FI-P1-001"), "matrix must include image failure separation scenario")
assertTrue(matrix.contains("P0 FAIL >= 1"), "matrix must include P0 auto blocking rule")

assertTrue(runbook.contains("토큰 만료"), "runbook must include token expiry injection steps")
assertTrue(runbook.contains("네트워크 단절"), "runbook must include offline injection steps")
assertTrue(runbook.contains("위치 튐/저정확도"), "runbook must include GPS jump/accuracy steps")

assertTrue(template.contains("재현 절차"), "result template must include reproduction steps section")
assertTrue(template.contains("기대값"), "result template must include expected result section")
assertTrue(template.contains("실제값"), "result template must include actual result section")
assertTrue(template.contains("PASS | FAIL | BLOCKED"), "result template must include pass/fail decision")

assertTrue(checklist.contains("참조 매트릭스"), "release checklist must reference fault matrix")
assertTrue(checklist.contains("릴리즈 PR 본문에 매트릭스 링크"), "release checklist must require PR evidence links")

print("PASS: fault injection matrix unit checks")
