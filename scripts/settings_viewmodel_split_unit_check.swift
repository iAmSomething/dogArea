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

let mainFile = load("dogArea/Views/ProfileSettingView/SettingViewModel.swift")
let profileEditing = load("dogArea/Views/ProfileSettingView/SettingViewModelSupport/SettingViewModel+ProfileEditing.swift")
let petManagement = load("dogArea/Views/ProfileSettingView/SettingViewModelSupport/SettingViewModel+PetManagement.swift")
let sessionSync = load("dogArea/Views/ProfileSettingView/SettingViewModelSupport/SettingViewModel+SessionSync.swift")
let seasonSummaryService = load("dogArea/Source/Domain/Profile/Services/SettingsSeasonProfileSummaryService.swift")
let seasonSummaryModel = load("dogArea/Source/Domain/Profile/Models/SeasonProfileSummary.swift")

assertTrue(mainFile.contains("let seasonProfileSummaryService: SettingsSeasonProfileSummaryProviding"), "SettingViewModel should inject season summary service")
assertTrue(!mainFile.contains("struct StoredSeasonState: Decodable"), "SettingViewModel main file should not decode season summary inline")
assertTrue(profileEditing.contains("func updateProfileDetails(\n        profileName:"), "profile editing support should own async profile save path")
assertTrue(petManagement.contains("func addPet("), "pet management support should own add-pet path")
assertTrue(sessionSync.contains("func bindAuthSessionSync()"), "session sync support should own auth-session binding")
assertTrue(sessionSync.contains("seasonProfileSummaryService.loadSummary()"), "session sync support should delegate season summary loading")
assertTrue(seasonSummaryService.contains("protocol SettingsSeasonProfileSummaryProviding"), "season summary service should define protocol contract")
assertTrue(seasonSummaryModel.contains("struct SeasonProfileSummary"), "season summary model should live in dedicated model file")

print("PASS: settings viewmodel split unit checks")
