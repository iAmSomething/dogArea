//
//  UserdefaultSetting.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import Foundation

class UserdefaultSetting {
    enum keyValue: String {
        case userId = "userId"
        case userName = "userName"
        case userProfile = "userProfile"
        case profileMessage = "profileMessage"
        case petInfo = "petInfo"
        case selectedPetId = "selectedPetId"
        case petSelectionScoreMap = "petSelectionScoreMap"
        case petSelectionRecentPetId = "petSelectionRecentPetId"
        case petSelectionEvents = "petSelectionEvents"
        case walkStartCountdownEnabled = "walkStartCountdownEnabled"
        case walkPointRecordMode = "walkPointRecordMode"
        case seasonCatchupBuffSnapshot = "seasonCatchupBuffSnapshot"
        case createdAt = "createdAt"
        case nonce = "nonce"
    }

    static var shared = UserdefaultSetting()
    static let selectedPetDidChangeNotification = PetSelectionStore.selectedPetDidChangeNotification
    static let seasonCatchupBuffDidUpdateNotification = Notification.Name("userdefault.seasonCatchupBuffDidUpdate")

    let userDefaults: UserDefaults
    let profileStore: ProfileStoring
    let petSelectionStore: PetSelectionStoring
    let walkSessionMetadataStore: WalkSessionMetadataStore

    init(
        userDefaults: UserDefaults = .standard,
        profileStore: ProfileStoring = ProfileStore.shared,
        petSelectionStore: PetSelectionStoring = PetSelectionStore.shared,
        walkSessionMetadataStore: WalkSessionMetadataStore = .shared
    ) {
        self.userDefaults = userDefaults
        self.profileStore = profileStore
        self.petSelectionStore = petSelectionStore
        self.walkSessionMetadataStore = walkSessionMetadataStore
    }

    func savenonce(nonce: Double) {
        userDefaults.setValue(nonce, forKey: keyValue.nonce.rawValue)
    }

    func save(
        id: String,
        name: String,
        profile: String?,
        profileMessage: String? = nil,
        pet: [PetInfo],
        createdAt: Double,
        selectedPetId: String? = nil
    ) {
        profileStore.save(
            id: id,
            name: name,
            profile: profile,
            profileMessage: profileMessage,
            pet: pet,
            createdAt: createdAt,
            selectedPetId: selectedPetId
        )
    }

    func getValue() -> UserInfo? {
        profileStore.getValue()
    }

    #if DEBUG
    func removeAll() {
        profileStore.removeAll()
        petSelectionStore.clearSelectionState()
        walkSessionMetadataStore.clearPreferences()
        userDefaults.removeObject(forKey: keyValue.selectedPetId.rawValue)
        userDefaults.removeObject(forKey: keyValue.walkStartCountdownEnabled.rawValue)
        userDefaults.removeObject(forKey: keyValue.walkPointRecordMode.rawValue)
    }
    #endif
}

extension Notification.Name {
    static let walkPointRecordedForQuest = Notification.Name("walk.point.recorded.for.quest")
    static let authSessionDidChange = Notification.Name("auth.session.didChange")
    static let openWalkHistoryRequested = Notification.Name("walk.history.requested")
    static let openWalkDetailRequested = Notification.Name("walk.detail.requested")
}
