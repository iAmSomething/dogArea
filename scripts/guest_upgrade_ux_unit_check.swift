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
Check.assertTrue(mapStart.contains("requireMember(trigger: .walkStart)"), "walk start should be member-gated")
Check.assertTrue(image.contains("requireMember(trigger: .imageGenerator)"), "image generation should be member-gated")
Check.assertTrue(walkList.contains("requireMember(trigger: .walkHistory)"), "walk list should provide login-to-sync path")

if Check.failed {
    exit(1)
}

print("All guest upgrade UX checks passed.")
