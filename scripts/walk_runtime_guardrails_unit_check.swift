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

let doc = load("docs/walk-runtime-guardrails-v1.md")
let checklist = load("docs/release-regression-checklist-v1.md")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let watchViewModel = load("dogAreaWatch Watch App/ContentsViewModel.swift")

assertTrue(doc.contains("위치 샘플 유효성"), "doc must include location sample validation section")
assertTrue(doc.contains("권한 강등 안전 일시중지"), "doc must include authorization downgrade section")
assertTrue(doc.contains("타이머 드리프트 보정"), "doc must include timer drift section")

assertTrue(mapViewModel.contains("locationAccuracyThreshold"), "view model must define horizontal accuracy threshold")
assertTrue(mapViewModel.contains("jumpSpeedThreshold"), "view model must define jump speed threshold")
assertTrue(mapViewModel.contains("validateWalkLocationSample"), "view model must validate walk location samples")
assertTrue(mapViewModel.contains("pauseWalkForAuthorizationDowngrade"), "view model must pause walk when authorization downgrades")
assertTrue(mapViewModel.contains("syncState"), "watch action enum must support syncState")
assertTrue(mapViewModel.contains("payload[\"sent_at\"]"), "view model should use sent_at fallback for action id")
assertTrue(mapViewModel.contains("Date().timeIntervalSince(self.startTime)"), "timer must use wall-clock correction")
assertTrue(mapViewModel.contains("runtimeGuardStatusText"), "view model must expose runtime guard status text")

assertTrue(mapView.contains("runtimeGuardBanner"), "map view must render runtime guard banner")

assertTrue(watchViewModel.contains("case syncState"), "watch app must define syncState action")
assertTrue(watchViewModel.contains("sendAction(.syncState)"), "watch app should request sync when reachable")

assertTrue(checklist.contains("저정확도/점프 GPS"), "checklist must include low-accuracy/jump scenario")
assertTrue(checklist.contains("권한 강등"), "checklist must include authorization downgrade scenario")
assertTrue(checklist.contains("syncState"), "checklist must include syncState scenario")

print("PASS: walk runtime guardrails unit checks")
