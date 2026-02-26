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

let userDefaults = load("dogArea/Source/UserdefaultSetting.swift")
let homeVM = load("dogArea/Views/HomeView/HomeViewModel.swift")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let settingVM = load("dogArea/Views/ProfileSettingView/SettingViewModel.swift")
let notificationView = load("dogArea/Views/ProfileSettingView/NotificationCenterView.swift")
let mapVM = load("dogArea/Views/MapView/MapViewModel.swift")
let startButton = load("dogArea/Views/MapView/MapSubViews/StartButtonView.swift")
let startModal = load("dogArea/Views/MapView/StartModalView.swift")

assertTrue(userDefaults.contains("case selectedPetId = \"selectedPetId\""), "UserdefaultSetting should persist selectedPetId")
assertTrue(userDefaults.contains("func setSelectedPetId(_ petId: String)"), "UserdefaultSetting should expose pet selection setter")
assertTrue(userDefaults.contains("func selectedPet(from userInfo: UserInfo? = nil) -> PetInfo?"), "UserdefaultSetting should expose selected pet resolver")

assertTrue(homeVM.contains("@Published var selectedPetId"), "HomeViewModel should keep selectedPetId state")
assertTrue(homeVM.contains("func selectPet(_ petId: String)"), "HomeViewModel should support pet selection")
assertTrue(homeView.contains("ForEach(viewModel.pets, id: \\.petId)"), "HomeView should render selectable pet chips")

assertTrue(settingVM.contains("func selectPet(_ petId: String)"), "SettingViewModel should support pet selection")
assertTrue(notificationView.contains("viewModel.selectedPet"), "NotificationCenterView should render selected pet info")
assertTrue(notificationView.contains("viewModel.selectPet"), "NotificationCenterView should allow selecting pet")

assertTrue(mapVM.contains("@Published var selectedPetId"), "MapViewModel should track selected pet for walk start")
assertTrue(mapVM.contains("func reloadSelectedPetContext()"), "MapViewModel should reload selected pet context")
assertTrue(startButton.contains("guard viewModel.hasSelectedPet else"), "StartButtonView should block walk start when no selected pet")
assertTrue(startModal.contains("let petName: String"), "StartModalView should receive selected pet name")

assertTrue(!homeVM.contains("pet.first"), "HomeViewModel should avoid pet.first hardcoding")
assertTrue(!homeView.contains("pet.first"), "HomeView should avoid pet.first hardcoding")
assertTrue(!notificationView.contains("pet.first"), "NotificationCenterView should avoid pet.first hardcoding")

print("PASS: multi-dog selection UX unit checks")
