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

struct Stage1Policy {
    let newTileScore: Int
    let holdTileDailyScore: Int
    let holdTileDailyCap: Int
    let decayGraceHours: Int
    let decayPerDay: Int
    let bronze: Int
    let silver: Int
    let gold: Int
    let platinum: Int

    static let v1 = Stage1Policy(
        newTileScore: 5,
        holdTileDailyScore: 1,
        holdTileDailyCap: 1,
        decayGraceHours: 48,
        decayPerDay: 2,
        bronze: 80,
        silver: 180,
        gold: 320,
        platinum: 520
    )
}

enum TileEvent {
    case newTile
    case holdTileDailyVisit(countToday: Int)
}

func score(for events: [TileEvent], policy: Stage1Policy = .v1) -> Int {
    var total = 0
    for event in events {
        switch event {
        case .newTile:
            total += policy.newTileScore
        case let .holdTileDailyVisit(countToday):
            if countToday <= policy.holdTileDailyCap {
                total += policy.holdTileDailyScore
            }
        }
    }
    return total
}

func applyDecay(rawScore: Int, ageHours: Int, policy: Stage1Policy = .v1) -> Int {
    guard ageHours > policy.decayGraceHours else {
        return rawScore
    }

    let overdueHours = ageHours - policy.decayGraceHours
    let decayDays = (overdueHours - 1) / 24 + 1
    let decayed = rawScore - decayDays * policy.decayPerDay
    return max(0, decayed)
}

struct RankRow {
    let userID: UUID
    let activeTileCount: Int
    let newTileCaptureCount: Int
    let lastContributionAt: Date
}

func sortedRank(_ rows: [RankRow]) -> [RankRow] {
    rows.sorted {
        if $0.activeTileCount != $1.activeTileCount {
            return $0.activeTileCount > $1.activeTileCount
        }
        if $0.newTileCaptureCount != $1.newTileCaptureCount {
            return $0.newTileCaptureCount > $1.newTileCaptureCount
        }
        if $0.lastContributionAt != $1.lastContributionAt {
            return $0.lastContributionAt < $1.lastContributionAt
        }
        return $0.userID.uuidString < $1.userID.uuidString
    }
}

func tier(for score: Int, policy: Stage1Policy = .v1) -> String {
    if score >= policy.platinum { return "Platinum" }
    if score >= policy.gold { return "Gold" }
    if score >= policy.silver { return "Silver" }
    if score >= policy.bronze { return "Bronze" }
    return "Rookie"
}

let doc = load("docs/season-weekly-policy-stage1-v1.md")
let schemaDoc = load("docs/supabase-schema-v1.md")
let migrationDoc = load("docs/supabase-migration.md")
let readme = load("README.md")
let report = load("docs/cycle-124-season-policy-report-2026-02-27.md")

assertTrue(doc.contains("신규 타일 점령: `+5`"), "policy doc should define new tile score")
assertTrue(doc.contains("동일 타일 유지 방문(일 1회): `+1`"), "policy doc should define hold tile score")
assertTrue(doc.contains("48시간"), "policy doc should define decay grace")
assertTrue(doc.contains("하루 `-2`"), "policy doc should define decay value")
assertTrue(doc.contains("활성 타일 수"), "policy doc should define tiebreak order")
assertTrue(doc.contains("`Bronze`: 80점 이상"), "policy doc should define tier thresholds")

assertTrue(schemaDoc.contains("주간 시즌 정책 고정(Stage 1)"), "schema doc should include stage1 season policy section")
assertTrue(migrationDoc.contains("시즌 Stage1 정책 검증 (#124)"), "migration ops doc should include stage1 verification")
assertTrue(readme.contains("docs/season-weekly-policy-stage1-v1.md"), "README should reference stage1 season policy doc")
assertTrue(report.contains("#124"), "cycle report should reference issue #124")

let exampleA = Array(repeating: TileEvent.newTile, count: 10)
assertTrue(score(for: exampleA) == 50, "10 new tiles should score 50")

assertTrue(applyDecay(rawScore: 12, ageHours: 48) == 12, "48h should not decay yet")
assertTrue(applyDecay(rawScore: 12, ageHours: 72) == 10, "72h should decay by 2")
assertTrue(applyDecay(rawScore: 3, ageHours: 120) == 0, "decay floor should clamp at zero")

let formatter = ISO8601DateFormatter()
let rows = [
    RankRow(
        userID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        activeTileCount: 12,
        newTileCaptureCount: 5,
        lastContributionAt: formatter.date(from: "2026-02-24T08:00:00Z")!
    ),
    RankRow(
        userID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        activeTileCount: 12,
        newTileCaptureCount: 5,
        lastContributionAt: formatter.date(from: "2026-02-24T08:00:00Z")!
    ),
    RankRow(
        userID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        activeTileCount: 10,
        newTileCaptureCount: 9,
        lastContributionAt: formatter.date(from: "2026-02-24T07:00:00Z")!
    )
]

let ranked = sortedRank(rows)
assertTrue(ranked.first?.userID.uuidString == "00000000-0000-0000-0000-000000000001", "tie should be deterministically resolved by user id")
assertTrue(ranked.last?.userID.uuidString == "00000000-0000-0000-0000-000000000003", "lower active tile count should rank lower")

assertTrue(tier(for: 79) == "Rookie", "79 should be rookie")
assertTrue(tier(for: 80) == "Bronze", "80 should be bronze")
assertTrue(tier(for: 180) == "Silver", "180 should be silver")
assertTrue(tier(for: 320) == "Gold", "320 should be gold")
assertTrue(tier(for: 520) == "Platinum", "520 should be platinum")

print("PASS: season policy stage1 unit checks")
