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

let doc = load("docs/walk-session-recovery-auto-end-v1.md")
let checklist = load("docs/release-regression-checklist-v1.md")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")
let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapSetting = load("dogArea/Views/MapView/MapSubViews/MapSettingView.swift")
let userDefaultsSetting = load("dogArea/Source/UserdefaultSetting.swift")

assertTrue(doc.contains("세션 임시저장"), "doc must include active session snapshot section")
assertTrue(doc.contains("재실행 복구 UX"), "doc must include recovery UX section")
assertTrue(doc.contains("자동 종료 정책(v1)"), "doc must include auto-end policy section")

assertTrue(mapViewModel.contains("ActiveWalkSessionSnapshot"), "view model must define active walk snapshot model")
assertTrue(mapViewModel.contains("prepareRecoverableSessionIfNeeded"), "view model must prepare recoverable session")
assertTrue(mapViewModel.contains("resumeRecoverableWalkSession"), "view model must support resume action")
assertTrue(mapViewModel.contains("discardRecoverableWalkSession"), "view model must support discard action")
assertTrue(mapViewModel.contains("persistActiveWalkSession"), "view model must persist active session")
assertTrue(mapViewModel.contains("handleAutoEndIfNeeded"), "view model must implement auto-end policy")
assertTrue(mapViewModel.contains("autoEndInactivityInterval"), "view model must define inactivity threshold")
assertTrue(mapViewModel.contains("watchSyncStatusText"), "view model must expose watch sync status text")
assertTrue(mapViewModel.contains("latestWatchActionText"), "view model must expose watch action status text")
assertTrue(mapViewModel.contains("UIApplication.willResignActiveNotification"), "view model must snapshot on lifecycle resign")
assertTrue(mapViewModel.contains("UIApplication.willTerminateNotification"), "view model must snapshot on lifecycle terminate")

assertTrue(mapView.contains("recoverableSessionBanner"), "map view must show recoverable session banner")
assertTrue(mapView.contains("watchStatusBanner"), "map view must show watch status banner")
assertTrue(mapView.contains("walkStatusMessage"), "map view must render walk status toast")

assertTrue(mapSetting.contains("자동 종료 정책"), "map setting must expose auto-end policy toggle")
assertTrue(mapSetting.contains("toggleWalkAutoEndPolicy"), "map setting toggle should call auto-end policy function")

assertTrue(userDefaultsSetting.contains("walkAutoEndPolicyEnabled"), "user defaults must persist auto-end policy setting")

assertTrue(checklist.contains("미종료 세션 복구 배너"), "checklist must include recovery banner scenario")
assertTrue(checklist.contains("무활동 30분"), "checklist must include auto-end inactivity scenario")

print("PASS: walk session recovery/auto-end unit checks")
