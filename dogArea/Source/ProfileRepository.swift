import Foundation

protocol ProfileRepository {
    func fetchUserInfo() -> UserInfo?
    func selectedPet(from userInfo: UserInfo?) -> PetInfo?
    @discardableResult
    func save(
        id: String,
        name: String,
        profile: String?,
        profileMessage: String?,
        pet: [PetInfo],
        createdAt: Double,
        selectedPetId: String?
    ) -> UserInfo?
    func setSelectedPetId(_ petId: String, source: String)
}

final class DefaultProfileRepository: ProfileRepository {
    static let shared = DefaultProfileRepository()

    private let userStore: UserdefaultSetting
    private let syncCoordinator: ProfileSyncCoordinator

    init(
        userStore: UserdefaultSetting = .shared,
        syncCoordinator: ProfileSyncCoordinator = .shared
    ) {
        self.userStore = userStore
        self.syncCoordinator = syncCoordinator
    }

    func fetchUserInfo() -> UserInfo? {
        userStore.getValue()
    }

    func selectedPet(from userInfo: UserInfo?) -> PetInfo? {
        userStore.selectedPet(from: userInfo)
    }

    @discardableResult
    func save(
        id: String,
        name: String,
        profile: String?,
        profileMessage: String?,
        pet: [PetInfo],
        createdAt: Double,
        selectedPetId: String?
    ) -> UserInfo? {
        userStore.save(
            id: id,
            name: name,
            profile: profile,
            profileMessage: profileMessage,
            pet: pet,
            createdAt: createdAt,
            selectedPetId: selectedPetId
        )
        guard let snapshot = userStore.getValue() else { return nil }
        syncCoordinator.enqueueSnapshot(userInfo: snapshot)
        syncCoordinator.flushIfNeeded(force: true)
        return snapshot
    }

    func setSelectedPetId(_ petId: String, source: String) {
        userStore.setSelectedPetId(petId, source: source)
    }
}
