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

let viewFile = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let infraFile = load("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")
let doc = load("docs/rival-stage3-client-ux-v1.md")
let readme = load("README.md")

assertTrue(viewFile.contains("enum RivalCompareScope"), "rival tab should define compare scope")
assertTrue(viewFile.contains("enum RivalReportReason"), "rival tab should define report reasons")
assertTrue(viewFile.contains("숨김/차단 관리"), "rival tab should provide moderation management sheet")
assertTrue(viewFile.contains("신고 사유 선택"), "rival tab should provide report reason dialog")
assertTrue(viewFile.contains("func refreshLeaderboard"), "rival view model should fetch leaderboard")
assertTrue(viewFile.contains("func blockAlias"), "rival view model should support block action")
assertTrue(viewFile.contains("func hideAlias"), "rival view model should support hide action")
assertTrue(viewFile.contains("rival.hidden.alias.codes.v1"), "rival hidden alias local key should exist")
assertTrue(viewFile.contains("rival.blocked.alias.codes.v1"), "rival blocked alias local key should exist")

assertTrue(infraFile.contains("protocol RivalLeagueServiceProtocol"), "supabase infrastructure should expose rival league protocol")
assertTrue(infraFile.contains("struct RivalLeagueService"), "supabase infrastructure should implement rival league service")
assertTrue(infraFile.contains("rpc/rpc_get_rival_leaderboard"), "rival league service should call leaderboard rpc")

assertTrue(doc.contains("Rival Stage3 Client UX v1"), "stage3 doc should exist")
assertTrue(doc.contains("신고/차단/숨기기"), "stage3 doc should define moderation UX")
assertTrue(readme.contains("docs/rival-stage3-client-ux-v1.md"), "README should reference stage3 doc")

print("PASS: rival stage3 client ux unit checks")
