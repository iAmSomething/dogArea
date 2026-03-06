import Foundation

struct Check {
    static var failed = false

    static func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            print("[PASS] \(message)")
        } else {
            failed = true
            print("[FAIL] \(message)")
        }
    }
}

func read(_ path: String) -> String {
    (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
}

func readMany(_ relativePaths: [String]) -> String {
    relativePaths.map(read).joined(separator: "\n")
}

let source = readMany([
    "dogArea/Source/UserdefaultSetting.swift",
    "dogArea/Source/AppSession/AppFeatureGate.swift",
    "dogArea/Source/AppSession/GuestDataUpgradeService.swift",
    "dogArea/Source/AppSession/AuthFlowCoordinator.swift"
])
let mapStart = read("dogArea/Views/MapView/MapSubViews/StartButtonView.swift")
let imageView = read("dogArea/Views/ImageGeneratorView/TextToImageView.swift")
let imageVM = read("dogArea/Views/ImageGeneratorView/ImageGenerateViewModel.swift")
let walkList = read("dogArea/Views/WalkListView/WalkListView.swift")
let mapView = read("dogArea/Views/MapView/MapView.swift")
let mapVM = read("dogArea/Views/MapView/MapViewModel.swift")

Check.assertTrue(source.contains("enum AppSessionState"), "session should be modeled as guest/member")
Check.assertTrue(source.contains("enum FeatureCapability"), "feature capability matrix should exist")
Check.assertTrue(source.contains("enum AppFeatureGate"), "feature gate module should exist")
Check.assertTrue(source.contains("func requestAccess(feature:"), "auth coordinator should expose centralized request method")
Check.assertTrue(mapStart.contains("requestAccess(feature: .walkWrite)"), "walk start should be gated through centralized matrix")
Check.assertTrue(imageView.contains("requestAccess(feature: .aiGeneration)"), "image view should use centralized ai gate")
Check.assertTrue(walkList.contains("requestAccess(feature: .cloudSync)"), "walk list sync CTA should use centralized gate")
Check.assertTrue(mapView.contains("canAccess(.cloudSync)"), "map backup banner should depend on central gate")
Check.assertTrue(source.contains("AppFeatureGate.isAllowed(.cloudSync"), "sync transport should be guarded before network")
Check.assertTrue(imageVM.contains("AppFeatureGate.isAllowed(.aiGeneration"), "image API layer should guard member-only calls")
Check.assertTrue(mapVM.contains("isCloudSyncAvailableForSession"), "map view model should check session-aware cloud sync availability")
Check.assertTrue(mapVM.contains("isNearbySocialAvailableForSession"), "map view model should check session-aware nearby availability")

if Check.failed {
    exit(1)
}

print("All feature gate architecture checks passed.")
