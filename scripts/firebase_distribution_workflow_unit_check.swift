import Foundation

struct Check {
    static var failed = false

    static func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            print("[PASS] \(message)")
        } else {
            failed = true
            print("[FAIL] \(message)")
        }
    }
}

func read(_ path: String) -> String {
    (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
}

let workflow = read(".github/workflows/firebase-distribution.yml")
let doc = read("docs/github-actions-firebase-distribution.md")

Check.assertTrue(workflow.contains("name: Firebase Distribution"), "workflow should exist with expected name")
Check.assertTrue(workflow.contains("push:"), "workflow should trigger on main push")
Check.assertTrue(workflow.contains("workflow_dispatch:"), "workflow should support manual dispatch")
Check.assertTrue(workflow.contains("IOS_DIST_CERT_P12_BASE64"), "workflow should validate iOS cert secret")
Check.assertTrue(workflow.contains("IOS_PROVISIONING_PROFILE_BASE64"), "workflow should validate iOS profile secret")
Check.assertTrue(workflow.contains("WATCH_PROVISIONING_PROFILE_BASE64"), "workflow should include optional watch profile branch")
Check.assertTrue(workflow.contains("xcodebuild \\"), "workflow should archive with xcodebuild")
Check.assertTrue(workflow.contains("-exportArchive"), "workflow should export IPA")
Check.assertTrue(workflow.contains("firebase appdistribution:distribute"), "workflow should upload to Firebase App Distribution")
Check.assertTrue(workflow.contains("Failure classification guide"), "workflow should contain failure classification step")

Check.assertTrue(doc.contains("GitHub Actions Firebase Distribution Runbook"), "runbook doc should exist")
Check.assertTrue(doc.contains("시크릿/변수"), "runbook should describe required secrets")
Check.assertTrue(doc.contains("watch profile 분기"), "runbook should document watch profile fallback")
Check.assertTrue(doc.contains("실패 분류 기준"), "runbook should document failure classification")
Check.assertTrue(doc.contains("리허설 실행"), "runbook should document workflow_dispatch rehearsal")

if Check.failed {
    exit(1)
}

print("All firebase distribution workflow checks passed.")
