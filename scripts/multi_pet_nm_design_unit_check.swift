import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let docPath = root.appendingPathComponent("docs/multi-pet-session-nm-v2.md")
let doc = String(decoding: try! Data(contentsOf: docPath), as: UTF8.self)

assertTrue(doc.contains("## 3. walk_session_pets 활성화 전략"), "doc should include activation strategy section")
assertTrue(doc.contains("단계 A: 스키마 보강"), "doc should include phased rollout for walk_session_pets")
assertTrue(doc.contains("## 4. 집계 변경 영향 분석"), "doc should include aggregation impact section")
assertTrue(doc.contains("all 모드"), "doc should define all-mode dedupe behavior")
assertTrue(doc.contains("## 5. 마이그레이션 리스크 정리"), "doc should include migration risk section")
assertTrue(doc.contains("## 7. 구현 착수 조건"), "doc should include implementation readiness checklist")

print("PASS: multi-pet N:M design unit checks")
