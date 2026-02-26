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
assertTrue(doc.contains("5분"), "doc must include rest candidate threshold")
assertTrue(doc.contains("12분"), "doc must include warning threshold")
assertTrue(doc.contains("15분"), "doc must include finalize threshold")
assertTrue(doc.contains("비활성화 불가"), "doc must state fixed policy")

assertTrue(mapViewModel.contains("ActiveWalkSessionSnapshot"), "view model must define active walk snapshot model")
assertTrue(mapViewModel.contains("prepareRecoverableSessionIfNeeded"), "view model must prepare recoverable session")
assertTrue(mapViewModel.contains("resumeRecoverableWalkSession"), "view model must support resume action")
assertTrue(mapViewModel.contains("discardRecoverableWalkSession"), "view model must support discard action")
assertTrue(mapViewModel.contains("finalizeRecoverableWalkSessionNow"), "view model must support finish-now action")
assertTrue(mapViewModel.contains("persistActiveWalkSession"), "view model must persist active session")
assertTrue(mapViewModel.contains("handleAutoEndIfNeeded"), "view model must implement auto-end policy")
assertTrue(mapViewModel.contains("restCandidateInterval"), "view model must define rest candidate threshold")
assertTrue(mapViewModel.contains("inactivityWarningInterval"), "view model must define warning threshold")
assertTrue(mapViewModel.contains("inactivityFinalizeInterval"), "view model must define finalize threshold")
assertTrue(mapViewModel.contains("watchSyncStatusText"), "view model must expose watch sync status text")
assertTrue(mapViewModel.contains("latestWatchActionText"), "view model must expose watch action status text")
assertTrue(mapViewModel.contains("UIApplication.willResignActiveNotification"), "view model must snapshot on lifecycle resign")
assertTrue(mapViewModel.contains("UIApplication.willTerminateNotification"), "view model must snapshot on lifecycle terminate")

assertTrue(mapView.contains("recoverableSessionBanner"), "map view must show recoverable session banner")
assertTrue(mapView.contains("지금 종료"), "map view must provide finish-now action")
assertTrue(mapView.contains("watchStatusBanner"), "map view must show watch status banner")
assertTrue(mapView.contains("walkStatusMessage"), "map view must render walk status toast")

assertTrue(mapSetting.contains("자동 종료 정책 v1(고정)"), "map setting must expose fixed auto-end policy label")
assertTrue(mapSetting.contains("toggleWalkAutoEndPolicy") == false, "map setting must not expose auto-end toggle")
assertTrue(mapSetting.contains("autoEndPolicySummaryText"), "map setting should show policy summary text")
assertTrue(mapSetting.contains("autoEndPolicyHintText"), "map setting should show policy hint text")
assertTrue(mapViewModel.contains("autoEndPolicySummaryText"), "view model should expose policy summary text")
assertTrue(mapViewModel.contains("autoEndPolicyHintText"), "view model should expose policy hint text")
assertTrue(userDefaultsSetting.contains("setWalkAutoEndPolicyEnabled") == false, "user defaults should not expose auto-end toggle setter")
assertTrue(userDefaultsSetting.contains("walkAutoEndPolicyEnabled()") == false, "user defaults should not expose auto-end toggle getter")

assertTrue(userDefaultsSetting.contains("WalkSessionMetadataStore"), "session metadata store must persist end reason/time")
assertTrue(userDefaultsSetting.contains("WalkSessionEndReason"), "session end reason enum must exist")

assertTrue(checklist.contains("미종료 세션 복구 배너"), "checklist must include recovery banner scenario")
assertTrue(checklist.contains("무이동 5분/12분/15분"), "checklist must include staged inactivity scenario")
assertTrue(checklist.contains("단계/판정 기준 문구"), "checklist should include policy copy visibility check")

print("PASS: walk session recovery/auto-end unit checks")
