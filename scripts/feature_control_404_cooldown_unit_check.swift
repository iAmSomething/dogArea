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

let infra = load("dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift")

assertTrue(
    infra.contains("feature.control.unavailable.until.v1"),
    "feature-control service should persist 404 cooldown marker key"
)
assertTrue(
    infra.contains("functionUnavailableCooldownSeconds: TimeInterval = 10 * 60"),
    "feature-control service should define cooldown duration for 404 guard"
)
assertTrue(
    infra.contains("guard isFunctionTemporarilyUnavailable(now: Date()) == false else"),
    "feature-control post path should short-circuit when cooldown is active"
)
assertTrue(
    infra.contains("if case .unexpectedStatusCode(404) = error"),
    "feature-control service should detect 404 and mark cooldown"
)
assertTrue(
    infra.contains("markFunctionTemporarilyUnavailable(now: Date())"),
    "feature-control service should mark cooldown on 404"
)
assertTrue(
    infra.contains("clearFunctionUnavailableMarker()"),
    "feature-control service should clear cooldown marker after successful call"
)

print("PASS: feature-control 404 cooldown unit checks")
