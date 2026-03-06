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

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let doc = load("docs/walk-point-auto-record-v1.md")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let mapSetting = load("dogArea/Views/MapView/MapSubViews/MapSettingView.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let userDefaultsSetting = loadMany([
    "dogArea/Source/UserdefaultSetting.swift",
    "dogArea/Source/AppSession/AppFeatureGate.swift",
    "dogArea/Source/AppSession/GuestDataUpgradeService.swift",
    "dogArea/Source/AppSession/AuthFlowCoordinator.swift"
])
let checklist = load("docs/release-regression-checklist-v1.md")

assertTrue(doc.contains("자동 기록 규칙(v1)"), "doc must include auto record rule section")
assertTrue(doc.contains("거리 `>= 12m`"), "doc must include distance threshold")
assertTrue(doc.contains("시간 `>= 8초`"), "doc must include interval threshold")

assertTrue(mapViewModel.contains("enum WalkPointRecordMode"), "view model must define point record mode")
assertTrue(mapViewModel.contains("toggleWalkPointRecordMode"), "view model must expose mode toggle")
assertTrue(mapViewModel.contains("handleAutoPointRecord"), "view model must implement auto record handler")
assertTrue(mapViewModel.contains("autoRecordMinDistance"), "view model must include distance threshold constant")
assertTrue(mapViewModel.contains("autoRecordMinInterval"), "view model must include interval threshold constant")
assertTrue(mapViewModel.contains("autoRecordNoiseDistance"), "view model must include noise filter")
assertTrue(mapViewModel.contains("didUpdateLocations") && mapViewModel.contains("handleAutoPointRecord(with: location)"), "location updates must drive auto recording")

assertTrue(mapSetting.contains("walkPointRecordMode.title"), "map setting must show point record mode label")
assertTrue(mapSetting.contains("toggleWalkPointRecordMode"), "map setting must toggle point record mode")

assertTrue(mapView.contains("AUTO"), "map view should display AUTO badge in auto mode")

assertTrue(userDefaultsSetting.contains("walkPointRecordMode"), "user defaults should persist point record mode")
assertTrue(userDefaultsSetting.contains("walkPointRecordModeRawValue"), "user defaults should provide point record mode getter")

assertTrue(checklist.contains("포인트 자동 기록 ON"), "release checklist should include auto-mode scenario")
assertTrue(checklist.contains("포인트 자동 기록 OFF"), "release checklist should include manual-mode scenario")

print("PASS: walk point auto record unit checks")
