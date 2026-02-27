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

    private let profileStore: ProfileStoring
    private let petSelectionStore: PetSelectionStoring
    private let syncCoordinator: ProfileSyncCoordinator

    init(
        profileStore: ProfileStoring = ProfileStore.shared,
        petSelectionStore: PetSelectionStoring = PetSelectionStore.shared,
        syncCoordinator: ProfileSyncCoordinator = .shared
    ) {
        self.profileStore = profileStore
        self.petSelectionStore = petSelectionStore
        self.syncCoordinator = syncCoordinator
    }

    func fetchUserInfo() -> UserInfo? {
        profileStore.getValue()
    }

    func selectedPet(from userInfo: UserInfo?) -> PetInfo? {
        petSelectionStore.selectedPet(from: userInfo ?? profileStore.getValue())
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
        profileStore.save(
            id: id,
            name: name,
            profile: profile,
            profileMessage: profileMessage,
            pet: pet,
            createdAt: createdAt,
            selectedPetId: selectedPetId
        )
        guard let snapshot = profileStore.getValue() else { return nil }
        syncCoordinator.enqueueSnapshot(userInfo: snapshot)
        syncCoordinator.flushIfNeeded(force: true)
        return snapshot
    }

    func setSelectedPetId(_ petId: String, source: String) {
        petSelectionStore.setSelectedPetId(petId, source: source)
    }
}
