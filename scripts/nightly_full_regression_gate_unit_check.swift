import Foundation

/// Validates that a required nightly regression contract condition holds.
/// - Parameters:
///   - condition: Condition to validate for the workflow/document contract.
///   - message: Failure message printed when the condition does not hold.
@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// Loads a repository-relative UTF-8 text file.
/// - Parameter path: Repository-relative path to load.
/// - Returns: Decoded file contents.
func load(_ path: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(path))
    return String(decoding: data, as: UTF8.self)
}

let nightly = load("docs/nightly-full-regression-gate-v1.md")
let matrix = load("docs/release-real-device-evidence-matrix-v1.md")
let readme = load("README.md")
let workflow = load(".github/workflows/nightly-full-regression-gate.yml")

assertTrue(nightly.contains("- Issue: #707"), "nightly gate doc must reference issue #707")
assertTrue(nightly.contains(".github/workflows/nightly-full-regression-gate.yml"), "nightly doc must bind the workflow file")
assertTrue(nightly.contains("scripts/run_nightly_full_regression_gate.sh"), "nightly doc must reference the runner script")
assertTrue(nightly.contains(".artifacts/nightly-full-regression"), "nightly doc must define the artifact root")
assertTrue(nightly.contains("manual_blocker_evidence_status.sh"), "nightly doc must link blocker evidence runner")
assertTrue(nightly.contains("긴 산책 세션"), "nightly gate doc must include long walk session axis")
assertTrue(nightly.contains("오프라인 후 복구"), "nightly gate doc must include offline recovery axis")
assertTrue(nightly.contains("nearby-presence 오류/복구"), "nightly gate doc must include nearby recovery axis")
assertTrue(nightly.contains("widget 상태 전이"), "nightly gate doc must include widget state transition axis")
assertTrue(nightly.contains("watch 큐/동기화/종료 요약"), "nightly gate doc must include watch queue axis")
assertTrue(nightly.contains("retry 1회"), "nightly gate doc must define flaky retry policy")
assertTrue(nightly.contains("HOLD"), "nightly gate doc must define hold rule")
assertTrue(nightly.contains("walk_long_session"), "nightly gate doc must define long walk bucket")
assertTrue(nightly.contains("offline_recovery"), "nightly gate doc must define offline bucket")
assertTrue(nightly.contains("nearby_presence_recovery"), "nightly gate doc must define nearby bucket")
assertTrue(nightly.contains("widget_state_transition"), "nightly gate doc must define widget bucket")
assertTrue(nightly.contains("watch_queue_sync"), "nightly gate doc must define watch bucket")
assertTrue(matrix.contains("## 증적 기본 세트"), "real-device evidence matrix must define evidence bundle")
assertTrue(matrix.contains("RD-001"), "real-device evidence matrix must define map case")
assertTrue(matrix.contains("RD-002"), "real-device evidence matrix must define offline recovery case")
assertTrue(matrix.contains("RD-003"), "real-device evidence matrix must define nearby recovery case")
assertTrue(matrix.contains("RD-004"), "real-device evidence matrix must define widget case")
assertTrue(matrix.contains("RD-005"), "real-device evidence matrix must define watch queue case")
assertTrue(matrix.contains("RD-006"), "real-device evidence matrix must define watch summary case")
assertTrue(matrix.contains("PASS / FAIL / HOLD"), "real-device evidence matrix must standardize final states")
assertTrue(matrix.contains("step-1"), "real-device evidence matrix must standardize screenshot naming")
assertTrue(matrix.contains("request_id"), "real-device evidence matrix must require request correlation when available")
assertTrue(readme.contains("docs/nightly-full-regression-gate-v1.md"), "README must index nightly gate doc")
assertTrue(readme.contains("docs/release-real-device-evidence-matrix-v1.md"), "README must index real-device evidence matrix")
assertTrue(workflow.contains("name: nightly-full-regression-gate"), "workflow must use canonical nightly gate name")
assertTrue(workflow.contains("schedule:"), "workflow must run on a schedule")
assertTrue(workflow.contains("workflow_dispatch:"), "workflow must support manual dispatch")
assertTrue(workflow.contains("run_nightly_full_regression_gate.sh"), "workflow must run the nightly regression runner")
assertTrue(workflow.contains(".artifacts/nightly-full-regression"), "workflow must upload the nightly artifact root")
assertTrue(workflow.contains("actions/upload-artifact@v4"), "workflow must upload nightly artifacts")

print("PASS: nightly full regression gate unit checks")
