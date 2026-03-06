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
let root = read("dogArea/Views/GlobalViews/BaseView/RootView.swift")
let home = read("dogArea/Views/HomeView/HomeView.swift")
let homeVM = readMany([
    "dogArea/Views/HomeView/HomeViewModel.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+AreaProgress.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift",
    "dogArea/Source/Domain/Home/Models/HomeMissionModels.swift",
    "dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift",
    "dogArea/Source/Domain/Home/Stores/SeasonMotionStore.swift"
])

Check.assertTrue(source.contains("struct GuestDataUpgradeSnapshot"), "snapshot model must exist")
Check.assertTrue(source.contains("struct GuestDataUpgradeReport"), "upgrade report model must exist")
Check.assertTrue(source.contains("final class GuestDataUpgradeService"), "upgrade service must exist")
Check.assertTrue(source.contains("func pendingPrompt(for userId:"), "service should expose prompt detection")
Check.assertTrue(source.contains("func runUpgrade(for userId:"), "service should expose upgrade execution")
Check.assertTrue(source.contains("requeuePermanentFailures"), "outbox should support manual retry requeue")
Check.assertTrue(source.contains("contains(where: { $0.idempotencyKey == idempotencyKey })"), "outbox enqueue must block duplicate idempotency keys")
Check.assertTrue(source.contains("pendingGuestDataUpgradePrompt"), "auth coordinator must track upgrade prompt state")
Check.assertTrue(source.contains("startGuestDataUpgrade(forceRetry:"), "auth coordinator must trigger background migration")
Check.assertTrue(root.contains("GuestDataUpgradePromptSheetView"), "root should present guest data import sheet")
Check.assertTrue(root.contains("GuestDataUpgradeResultBanner"), "root should expose upgrade result feedback banner")
Check.assertTrue(home.contains("guestDataUpgradeCard"), "home view should display migration report card")
Check.assertTrue(homeVM.contains("guestDataUpgradeReport"), "home view model should load latest migration report")

if Check.failed {
    exit(1)
}

print("All guest data upgrade checks passed.")
