import Foundation

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// 저장소 루트 기준 상대 경로의 UTF-8 텍스트 파일을 읽습니다.
/// - Parameter relativePath: 저장소 루트 기준 상대 경로입니다.
/// - Returns: 파일 본문 문자열입니다.
func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let contentView = load("dogAreaWatch Watch App/ContentView.swift")
let controlSurfaceView = load("dogAreaWatch Watch App/WatchControlSurfaceView.swift")
let statusSummaryView = load("dogAreaWatch Watch App/WatchMainStatusSummaryView.swift")
let actionDockView = load("dogAreaWatch Watch App/WatchPrimaryActionDockView.swift")
let bannerView = load("dogAreaWatch Watch App/WatchActionBannerView.swift")
let doc = load("docs/watch-control-surface-density-v1.md")
let readme = load("README.md")
let prCheck = load("scripts/ios_pr_check.sh")

assertTrue(contentView.contains("WatchControlSurfaceView"), "watch content should delegate the control page hierarchy to WatchControlSurfaceView")
assertTrue(!contentView.contains("safeAreaInset(edge: .bottom"), "watch control page should not use a bottom inset overlay for CTA any more")
assertTrue(controlSurfaceView.contains("watch.main.controlSurface"), "control surface should expose a stable accessibility identifier")
assertTrue(controlSurfaceView.contains("WatchMainStatusSummaryView"), "control surface should include the status summary section")
assertTrue(controlSurfaceView.contains("WatchPrimaryActionDockView"), "control surface should include the action block section")
assertTrue(!controlSurfaceView.contains("WatchActionBannerView"), "control surface should remove feedback from the primary surface")
assertTrue(contentView.contains("WatchActionBannerView"), "information surface should host the feedback banner")
assertTrue(!statusSummaryView.contains("compactPetContext"), "status summary should remove compact idle pet context from the control page")
assertTrue(actionDockView.contains("showsBackground"), "action block should support rendering without its own elevated background")
assertTrue(bannerView.contains("enum WatchActionBannerStyle"), "watch banner should define explicit card/inline styles")
assertTrue(doc.contains("#737"), "watch control surface density doc should mention issue #737")
assertTrue(doc.contains("#738"), "watch control surface density doc should mention issue #738")
assertTrue(doc.contains("WatchControlSurfaceView"), "watch control surface density doc should document the integrated surface")
assertTrue(doc.contains("info page"), "watch control surface density doc should describe the info-page secondary information rule")
assertTrue(readme.contains("docs/watch-control-surface-density-v1.md"), "README should index the watch control surface density doc")
assertTrue(prCheck.contains("swift scripts/watch_control_surface_density_unit_check.swift"), "ios_pr_check should include the watch control surface density unit check")

print("PASS: watch control surface density unit checks")
