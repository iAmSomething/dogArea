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

let mapSource = load("dogArea/Views/MapView/MapViewModel.swift")
let rivalSource = load("dogArea/Views/ProfileSettingView/RivalTabViewModel.swift")

func verifyTracer(_ source: String, tracerName: String) {
    assertTrue(
        source.contains("private static var consecutiveIdleWindows: Int = 0"),
        "\(tracerName) should track consecutive idle windows"
    )
    assertTrue(
        source.contains("private static let idleWindowStopThreshold: Int = 30"),
        "\(tracerName) should define an idle-window stop threshold"
    )
    assertTrue(
        source.contains("let shouldStopHeartbeat = consecutiveIdleWindows >= idleWindowStopThreshold"),
        "\(tracerName) should determine when to stop heartbeat"
    )
    assertTrue(
        source.contains("let timerToCancel = shouldStopHeartbeat ? heartbeatTimer : nil"),
        "\(tracerName) should preserve timer reference for safe cancel"
    )
    assertTrue(
        source.contains("timerToCancel?.cancel()"),
        "\(tracerName) should cancel heartbeat timer when idle threshold is reached"
    )
    assertTrue(
        source.contains("if snapshot.isEmpty {\n            consecutiveIdleWindows += 1\n        } else {\n            consecutiveIdleWindows = 0\n        }"),
        "\(tracerName) should reset idle counter when events exist"
    )
}

verifyTracer(mapSource, tracerName: "Map tracer")
verifyTracer(rivalSource, tracerName: "Rival tracer")

print("PASS: corelocation trace heartbeat autostop unit checks")
