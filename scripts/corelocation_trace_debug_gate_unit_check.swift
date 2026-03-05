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

func section(_ source: String, from startMarker: String, to endMarker: String) -> String {
    guard let startRange = source.range(of: startMarker) else { return "" }
    guard let endRange = source.range(of: endMarker, range: startRange.upperBound..<source.endIndex) else { return "" }
    return String(source[startRange.upperBound..<endRange.lowerBound])
}

func verifyTracerGating(
    source: String,
    tracerName: String,
    debugMarker: String,
    releaseMarker: String
) {
    assertTrue(
        source.contains("#if DEBUG"),
        "\(tracerName) should be gated by #if DEBUG"
    )
    assertTrue(
        source.contains("#else"),
        "\(tracerName) should provide a release fallback"
    )
    assertTrue(
        source.contains("#endif"),
        "\(tracerName) should close conditional compilation"
    )

    let debugSection = section(source, from: debugMarker, to: "#else")
    assertTrue(
        debugSection.contains("startHeartbeatIfNeeded()"),
        "\(tracerName) debug section should keep tracer behavior"
    )
    assertTrue(
        debugSection.contains("DispatchSource.makeTimerSource"),
        "\(tracerName) debug section should still own heartbeat timer"
    )

    let releaseSection = section(source, from: releaseMarker, to: "#endif")
    assertTrue(
        releaseSection.contains("_ = event"),
        "\(tracerName) release section should no-op the event input"
    )
    assertTrue(
        releaseSection.contains("_ = detail"),
        "\(tracerName) release section should no-op the detail input"
    )
    assertTrue(
        releaseSection.contains("_ = file"),
        "\(tracerName) release section should no-op the file input"
    )
    assertTrue(
        releaseSection.contains("_ = line"),
        "\(tracerName) release section should no-op the line input"
    )
    assertTrue(
        releaseSection.contains("DispatchSource.makeTimerSource") == false,
        "\(tracerName) release section must not create heartbeat timers"
    )
}

let mapSource = load("dogArea/Views/MapView/MapViewModel.swift")
let rivalSource = load("dogArea/Views/ProfileSettingView/RivalTabViewModel.swift")

verifyTracerGating(
    source: mapSource,
    tracerName: "Map tracer",
    debugMarker: "private enum MapCoreLocationCallTracer {",
    releaseMarker: "#else\nprivate enum MapCoreLocationCallTracer {"
)
verifyTracerGating(
    source: rivalSource,
    tracerName: "Rival tracer",
    debugMarker: "private enum RivalCoreLocationCallTracer {",
    releaseMarker: "#else\nprivate enum RivalCoreLocationCallTracer {"
)

print("PASS: corelocation trace debug gate unit checks")
