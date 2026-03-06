import Foundation

/// 설정 화면의 반려견 추가/대표 변경/활성 상태 관리를 전담합니다.
protocol SettingsPetManaging {
    /// 새 반려견을 추가하고 최신 사용자 스냅샷을 반환합니다.
    func addPet(
        draft: PetProfileDraft,
        imageData: Data?,
        currentUser: UserInfo
    ) async throws -> UserInfo

    /// 대표 반려견을 변경하고 최신 사용자 스냅샷을 반환합니다.
    func setPrimaryPet(
        petId: String,
        currentUser: UserInfo
    ) throws -> UserInfo

    /// 반려견 활성 상태를 변경하고 최신 사용자 스냅샷을 반환합니다.
    func setPetActive(
        petId: String,
        isActive: Bool,
        currentUser: UserInfo
    ) throws -> UserInfo
}

enum SettingsPetManagementError: LocalizedError, Equatable {
    case userNotFound
    case petNotFound
    case cannotDeactivateLastActivePet
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "사용자 정보를 불러오지 못했습니다. 다시 시도해주세요."
        case .petNotFound:
            return "대상 반려견 정보를 찾지 못했습니다."
        case .cannotDeactivateLastActivePet:
            return "활성 반려견은 최소 1마리 이상 유지되어야 합니다."
        case .imageEncodingFailed:
            return "이미지 처리에 실패했습니다. 다른 사진으로 다시 시도해주세요."
        }
    }
}

final class SettingsPetManagementService: SettingsPetManaging {
    private let profileRepository: ProfileRepository
    private let imageRepository: ProfileImageRepository

    init(
        profileRepository: ProfileRepository = DefaultProfileRepository.shared,
        imageRepository: ProfileImageRepository = SupabaseProfileImageRepository.shared
    ) {
        self.profileRepository = profileRepository
        self.imageRepository = imageRepository
    }

    /// 새 반려견을 추가하고 최신 사용자 스냅샷을 반환합니다.
    /// - Parameters:
    ///   - draft: 추가할 반려견 입력 초안입니다.
    ///   - imageData: 선택된 반려견 이미지 JPEG 데이터입니다.
    ///   - currentUser: 현재 사용자 스냅샷입니다.
    /// - Returns: 저장 및 동기화가 반영된 최신 사용자 스냅샷입니다.
    func addPet(
        draft: PetProfileDraft,
        imageData: Data?,
        currentUser: UserInfo
    ) async throws -> UserInfo {
        let validated = try draft.validated()
        let uploadedURL: String?
        if let imageData {
            uploadedURL = try await imageRepository.uploadPetProfileImage(data: imageData, ownerId: currentUser.id)
        } else {
            uploadedURL = nil
        }

        var pets = currentUser.pet
        pets.append(
            PetInfo(
                petName: validated.petName,
                petProfile: uploadedURL,
                breed: validated.breed,
                ageYears: validated.ageYears,
                gender: validated.gender,
                caricatureURL: nil,
                caricatureStatus: nil,
                caricatureProvider: nil,
                isActive: true
            )
        )
        let selectedPetId = resolvedSelectedPetId(afterSaving: pets, requested: currentUser.selectedPetId)
        guard let snapshot = profileRepository.save(
            id: currentUser.id,
            name: currentUser.name,
            profile: currentUser.profile,
            profileMessage: currentUser.profileMessage,
            pet: pets,
            createdAt: currentUser.createdAt,
            selectedPetId: selectedPetId
        ) else {
            throw SettingsPetManagementError.userNotFound
        }
        return snapshot
    }

    /// 대표 반려견을 변경하고 최신 사용자 스냅샷을 반환합니다.
    /// - Parameters:
    ///   - petId: 대표로 지정할 반려견 식별자입니다.
    ///   - currentUser: 현재 사용자 스냅샷입니다.
    /// - Returns: 저장 및 동기화가 반영된 최신 사용자 스냅샷입니다.
    func setPrimaryPet(
        petId: String,
        currentUser: UserInfo
    ) throws -> UserInfo {
        guard currentUser.pet.contains(where: { $0.petId == petId && $0.isActive }) else {
            throw SettingsPetManagementError.petNotFound
        }
        guard let snapshot = profileRepository.save(
            id: currentUser.id,
            name: currentUser.name,
            profile: currentUser.profile,
            profileMessage: currentUser.profileMessage,
            pet: currentUser.pet,
            createdAt: currentUser.createdAt,
            selectedPetId: petId
        ) else {
            throw SettingsPetManagementError.userNotFound
        }
        profileRepository.setSelectedPetId(petId, source: "settings_pet_primary")
        return snapshot
    }

    /// 반려견 활성 상태를 변경하고 최신 사용자 스냅샷을 반환합니다.
    /// - Parameters:
    ///   - petId: 활성 상태를 변경할 반려견 식별자입니다.
    ///   - isActive: 변경할 활성 상태입니다.
    ///   - currentUser: 현재 사용자 스냅샷입니다.
    /// - Returns: 저장 및 동기화가 반영된 최신 사용자 스냅샷입니다.
    func setPetActive(
        petId: String,
        isActive: Bool,
        currentUser: UserInfo
    ) throws -> UserInfo {
        var pets = currentUser.pet
        guard let index = pets.firstIndex(where: { $0.petId == petId }) else {
            throw SettingsPetManagementError.petNotFound
        }

        let activeCount = pets.filter(\.isActive).count
        if isActive == false, pets[index].isActive, activeCount <= 1 {
            throw SettingsPetManagementError.cannotDeactivateLastActivePet
        }

        pets[index].isActive = isActive
        let selectedPetId = resolvedSelectedPetId(afterSaving: pets, requested: currentUser.selectedPetId)
        guard let snapshot = profileRepository.save(
            id: currentUser.id,
            name: currentUser.name,
            profile: currentUser.profile,
            profileMessage: currentUser.profileMessage,
            pet: pets,
            createdAt: currentUser.createdAt,
            selectedPetId: selectedPetId
        ) else {
            throw SettingsPetManagementError.userNotFound
        }
        if let selectedPetId {
            profileRepository.setSelectedPetId(selectedPetId, source: isActive ? "settings_pet_reactivate" : "settings_pet_deactivate")
        }
        return snapshot
    }

    /// 저장 이후 사용할 대표 반려견 식별자를 계산합니다.
    /// - Parameters:
    ///   - pets: 저장 대상 반려견 목록입니다.
    ///   - requested: 우선적으로 유지하려는 반려견 식별자입니다.
    /// - Returns: 활성 반려견 우선 규칙을 반영한 대표 반려견 식별자입니다.
    private func resolvedSelectedPetId(afterSaving pets: [PetInfo], requested: String?) -> String? {
        let activePets = pets.filter(\.isActive)
        guard activePets.isEmpty == false else { return nil }
        if let requested, activePets.contains(where: { $0.petId == requested }) {
            return requested
        }
        return activePets.first?.petId
    }
}
