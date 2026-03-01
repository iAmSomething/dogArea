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

let policyDoc = load("docs/rival-privacy-policy-stage1-v1.md")
let hardGuardDoc = load("docs/rival-privacy-hard-guard-v1.md")
let nearbyDoc = load("docs/nearby-anonymous-hotspot-v1.md")
let readme = load("README.md")

assertTrue(policyDoc.contains("# Rival Privacy Policy Stage1 v1"), "policy doc title should exist")
assertTrue(policyDoc.contains("기본 비활성(opt-in)"), "policy doc should define opt-in default")
assertTrue(policyDoc.contains("sample_count >= 20"), "policy doc should define k-anon threshold")
assertTrue(policyDoc.contains("주간 30분 / 야간 60분"), "policy doc should define delay windows")
assertTrue(policyDoc.contains("동의/철회 상태 전이"), "policy doc should include state transition section")
assertTrue(policyDoc.contains("OFF -> ON_PENDING"), "policy doc should define opt-in transition")
assertTrue(policyDoc.contains("ON -> OFF_REVOKED"), "policy doc should define revoke transition")
assertTrue(policyDoc.contains("개인정보 보호 리뷰 체크리스트"), "policy doc should include review checklist")
assertTrue(policyDoc.contains("미성년/민감 계정"), "policy doc should include sensitive account protection")

assertTrue(hardGuardDoc.contains("k >= 20"), "hard guard doc should align with k-anon threshold")
assertTrue(hardGuardDoc.contains("주간 30분"), "hard guard doc should include daytime delay")
assertTrue(nearbyDoc.contains("k>=20"), "nearby doc should include k-anon threshold wording")

assertTrue(readme.contains("docs/rival-privacy-policy-stage1-v1.md"), "README should reference stage1 rival privacy policy doc")

print("PASS: rival privacy policy stage1 unit checks")
