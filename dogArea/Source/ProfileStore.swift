import Foundation

protocol ProfileStoring {
    func save(
        id: String,
        name: String,
        profile: String?,
        profileMessage: String?,
        pet: [PetInfo],
        createdAt: Double,
        selectedPetId: String?
    )
    func getValue() -> UserInfo?
    func removeAll()
    @discardableResult
    func updatePetCaricature(
        status: CaricatureStatus,
        targetPetId: String,
        caricatureURL: String?,
        provider: String?
    ) -> UserInfo?
}

final class ProfileStore: ProfileStoring {
    static let shared = ProfileStore()

    private enum Key {
        static let userId = "userId"
        static let userName = "userName"
        static let userProfile = "userProfile"
        static let profileMessage = "profileMessage"
        static let petInfo = "petInfo"
        static let selectedPetId = "selectedPetId"
        static let petSelectionRecentPetId = "petSelectionRecentPetId"
        static let createdAt = "createdAt"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
        let normalizedPets = normalizePets(pet)
        let resolvedSelectedPetId = resolveSelectedPetId(
            in: normalizedPets,
            requested: selectedPetId
        )
        defaults.setValue(id, forKey: Key.userId)
        defaults.setValue(name, forKey: Key.userName)
        defaults.setValue(profile, forKey: Key.userProfile)
        defaults.setValue(profileMessage, forKey: Key.profileMessage)
        defaults.setStructArray(normalizedPets, forKey: Key.petInfo)
        defaults.setValue(resolvedSelectedPetId, forKey: Key.selectedPetId)
        defaults.setValue(resolvedSelectedPetId, forKey: Key.petSelectionRecentPetId)
        defaults.setValue(createdAt, forKey: Key.createdAt)
    }

    func getValue() -> UserInfo? {
        guard let id = defaults.string(forKey: Key.userId),
              let name = defaults.string(forKey: Key.userName) else {
            return nil
        }

        let storedPets = defaults.structArrayData(PetInfo.self, forKey: Key.petInfo)
        let pets = normalizePets(storedPets)
        let createdAt = defaults.double(forKey: Key.createdAt)
        let selectedPetId = resolveSelectedPetId(
            in: pets,
            requested: defaults.string(forKey: Key.selectedPetId)
        )
        let shouldMigrate = storedPets != pets ||
        selectedPetId != defaults.string(forKey: Key.selectedPetId)

        if shouldMigrate {
            save(
                id: id,
                name: name,
                profile: defaults.string(forKey: Key.userProfile),
                profileMessage: defaults.string(forKey: Key.profileMessage),
                pet: pets,
                createdAt: createdAt,
                selectedPetId: selectedPetId
            )
        }

        return UserInfo(
            id: id,
            name: name,
            profile: defaults.string(forKey: Key.userProfile),
            profileMessage: defaults.string(forKey: Key.profileMessage),
            pet: pets,
            createdAt: createdAt
        )
    }

    func removeAll() {
        defaults.removeObject(forKey: Key.userId)
        defaults.removeObject(forKey: Key.userName)
        defaults.removeObject(forKey: Key.userProfile)
        defaults.removeObject(forKey: Key.profileMessage)
        defaults.removeObject(forKey: Key.petInfo)
    }

    @discardableResult
    func updatePetCaricature(
        status: CaricatureStatus,
        targetPetId: String,
        caricatureURL: String? = nil,
        provider: String? = nil
    ) -> UserInfo? {
        guard let current = getValue(), current.pet.isEmpty == false else {
            return nil
        }
        var pets = current.pet
        guard let index = pets.firstIndex(where: { $0.petId == targetPetId }) else {
            return nil
        }

        pets[index].caricatureStatus = status
        if let caricatureURL {
            pets[index].caricatureURL = caricatureURL
            pets[index].petProfile = caricatureURL
        }
        if let provider {
            pets[index].caricatureProvider = provider
        }

        save(
            id: current.id,
            name: current.name,
            profile: current.profile,
            profileMessage: current.profileMessage,
            pet: pets,
            createdAt: current.createdAt,
            selectedPetId: targetPetId
        )
        return getValue()
    }

    private func normalizePets(_ pets: [PetInfo]) -> [PetInfo] {
        var seen = Set<String>()
        return pets.map { pet in
            var normalized = pet
            if normalized.petId.isEmpty || seen.contains(normalized.petId) {
                normalized.petId = UUID().uuidString.lowercased()
            }
            seen.insert(normalized.petId)
            return normalized
        }
    }

    private func resolveSelectedPetId(in pets: [PetInfo], requested: String?) -> String? {
        let activePets = pets.filter(\.isActive)
        guard activePets.isEmpty == false else { return nil }
        if let requested, activePets.contains(where: { $0.petId == requested }) {
            return requested
        }
        if let stored = defaults.string(forKey: Key.selectedPetId),
           activePets.contains(where: { $0.petId == stored }) {
            return stored
        }
        return activePets.first?.petId
    }
}
