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

let app = read("dogArea/dogAreaApp.swift")
let root = read("dogArea/Views/GlobalViews/BaseView/RootView.swift")
let signIn = read("dogArea/Views/SigningView/SignInView.swift")
let mapStart = read("dogArea/Views/MapView/MapSubViews/StartButtonView.swift")
let image = read("dogArea/Views/ImageGeneratorView/TextToImageView.swift")
let walkList = read("dogArea/Views/WalkListView/WalkListView.swift")
let source = read("dogArea/Source/UserdefaultSetting.swift")

Check.assertTrue(app.contains("GuestEntryChoiceSheet"), "app should expose first-run split sheet")
Check.assertTrue(app.contains("shouldShowSignIn"), "app should control sign-in cover via coordinator")
Check.assertTrue(root.contains("pendingUpgradeRequest"), "root should host shared upgrade bottom sheet")
Check.assertTrue(source.contains("final class AuthFlowCoordinator"), "auth flow coordinator must exist")
Check.assertTrue(source.contains("MemberUpgradeSheetView"), "shared upgrade sheet view must exist")
Check.assertTrue(signIn.contains("allowDismiss"), "sign-in should support later/cancel path")
Check.assertTrue(signIn.contains("onAuthenticated"), "sign-in should use callback completion")
Check.assertTrue(source.contains("enum FeatureCapability"), "feature capability matrix should be defined")
Check.assertTrue(source.contains("enum AppFeatureGate"), "central feature gate module should exist")
Check.assertTrue(source.contains("func requestAccess(feature:"), "auth flow should expose centralized feature access request")
Check.assertTrue(mapStart.contains("requestAccess(feature: .walkWrite)"), "walk start should use centralized gate")
Check.assertTrue(image.contains("requestAccess(feature: .aiGeneration)"), "image generation should use centralized gate")
Check.assertTrue(walkList.contains("requestAccess(feature: .cloudSync)"), "walk list should use centralized gate for sync CTA")

if Check.failed {
    exit(1)
}

print("All guest upgrade UX checks passed.")
