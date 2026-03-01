import Foundation

@discardableResult
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() == false {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
    return true
}

func load(_ path: String) -> String {
    (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
}

let repo = load("dogArea/Source/Data/Walk/WalkRepository.swift")

assertTrue(repo.contains("protocol WalkRepositoryProtocol"), "WalkRepositoryProtocol should exist")
assertTrue(repo.contains("func fetchPolygons() -> [Polygon]"), "repository should expose polygon fetch")
assertTrue(repo.contains("func savePolygon(_ polygon: Polygon) -> [Polygon]"), "repository should expose polygon save")
assertTrue(repo.contains("func deletePolygon(id: UUID) -> [Polygon]"), "repository should expose polygon delete")
assertTrue(repo.contains("WalkFileCacheDataSource"), "file cache data source should exist")
assertTrue(repo.contains("outbox.enqueue(session:"), "outbox enqueue should remain in repository path")
assertTrue(repo.contains("func syncPending() async"), "repository should expose pending sync flush API")

print("PASS: walk repository contract checks")
