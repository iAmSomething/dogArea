//
//  SettingViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/13/23.
//

import Foundation
import Combine
import UIKit

struct SeasonProfileSummary: Equatable {
    let weekKey: String
    let score: Int
    let rankTier: SeasonRankTier
    let contributionCount: Int
}

final class SettingViewModel: ObservableObject {
    enum ProfileEditValidationError: LocalizedError {
        case userNotFound
        case invalidAgeRange
        case invalidDisplayName
        case invalidPetName
        case selectedPetNotFound
        case imageEncodingFailed
        case cannotDeactivateLastActivePet

        var errorDescription: String? {
            switch self {
            case .userNotFound:
                return "사용자 정보를 불러오지 못했습니다. 다시 로그인한 뒤 시도해주세요."
            case .invalidAgeRange:
                return "나이는 0~30 사이 숫자로 입력해주세요."
            case .invalidDisplayName:
                return "사용자 이름은 비워둘 수 없습니다."
            case .invalidPetName:
                return "반려견 이름은 비워둘 수 없습니다."
            case .selectedPetNotFound:
                return "선택된 반려견 정보를 찾지 못했습니다."
            case .imageEncodingFailed:
                return "이미지 처리에 실패했습니다. 다른 사진으로 다시 시도해주세요."
            case .cannotDeactivateLastActivePet:
                return "활성 반려견은 최소 1마리 이상 유지되어야 합니다."
            }
        }
    }

    @Published var polygonList: [Polygon] = []
    @Published var userName: String? = nil
    @Published var petName: String? = nil
    @Published var userInfo: UserInfo? = nil
    @Published var selectedPetId: String = ""
    @Published var selectedPet: PetInfo? = nil
    @Published var seasonProfileSummary: SeasonProfileSummary? = nil
    @Published var isCaricatureGenerating: Bool = false
    @Published var isAccountDeletionInProgress: Bool = false
    private let profileRepository: ProfileRepository
    private let imageRepository: ProfileImageRepository
    private let petManagementService: SettingsPetManaging
    private let accountDeletionService: AccountDeletionServiceProtocol
    private let authSessionStore: AuthSessionStoreProtocol
    private let walkRepository: WalkRepositoryProtocol
    private let featureFlags = FeatureFlagStore.shared
    private let metricTracker = AppMetricTracker.shared
    private let caricatureClient = CaricatureEdgeClient()
    private var cancellables: Set<AnyCancellable> = []

    var pets: [PetInfo] {
        userInfo?.pet ?? []
    }

    var activePets: [PetInfo] {
        pets.filter(\.isActive)
    }

    var inactivePets: [PetInfo] {
        pets.filter { $0.isActive == false }
    }

    init(
        profileRepository: ProfileRepository = DefaultProfileRepository.shared,
        imageRepository: ProfileImageRepository = SupabaseProfileImageRepository.shared,
        petManagementService: SettingsPetManaging = SettingsPetManagementService(),
        accountDeletionService: AccountDeletionServiceProtocol = SupabaseAccountDeletionService.shared,
        authSessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared,
        walkRepository: WalkRepositoryProtocol = WalkRepositoryContainer.shared
    ) {
        self.profileRepository = profileRepository
        self.imageRepository = imageRepository
        self.petManagementService = petManagementService
        self.accountDeletionService = accountDeletionService
        self.authSessionStore = authSessionStore
        self.walkRepository = walkRepository
        bindSelectedPetSync()
        bindAuthSessionSync()
        fetchModel()
        reloadUserInfo()
    }
    func fetchModel() {
        self.polygonList = self.walkRepository.fetchPolygons()
    }

    func reloadUserInfo() {
        self.userInfo = profileRepository.fetchUserInfo()
        self.selectedPet = profileRepository.selectedPet(from: userInfo)
        self.selectedPetId = selectedPet?.petId ?? ""
        self.userName = userInfo?.name
        self.petName = selectedPet?.petName
        reloadSeasonProfileSummary()
    }

    func selectPet(_ petId: String) {
        guard activePets.contains(where: { $0.petId == petId }) else { return }
        profileRepository.setSelectedPetId(petId, source: "setting")
        reloadUserInfo()
    }

    func updateProfileDetails(
        petName: String,
        profileMessage: String,
        breed: String,
        ageYearsText: String,
        gender: PetGender
    ) -> Result<Void, ProfileEditValidationError> {
        guard let current = profileRepository.fetchUserInfo() else {
            return .failure(.userNotFound)
        }

        let validatedUserDraft = UserProfileDraft(displayName: current.name, profileMessage: profileMessage)
        let validatedPetDraft = PetProfileDraft(
            petName: petName,
            breed: breed,
            ageYearsText: ageYearsText,
            gender: gender
        )

        let normalizedProfileMessage: String?
        let normalizedPet: ValidatedPetProfileDraft
        do {
            normalizedProfileMessage = try validatedUserDraft.validated().profileMessage
            normalizedPet = try validatedPetDraft.validated()
        } catch let error as ProfileEditorValidationError {
            switch error {
            case .invalidAgeRange:
                return .failure(.invalidAgeRange)
            case .invalidPetName:
                return .failure(.invalidPetName)
            case .invalidDisplayName:
                return .failure(.invalidDisplayName)
            }
        } catch {
            return .failure(.userNotFound)
        }

        var pets = current.pet
        let targetPetId = selectedPetId.isEmpty == false ? selectedPetId : pets.first(where: \.isActive)?.petId
        if let targetPetId,
           let index = pets.firstIndex(where: { $0.petId == targetPetId }) {
            pets[index].petName = normalizedPet.petName
            pets[index].breed = normalizedPet.breed
            pets[index].ageYears = normalizedPet.ageYears
            pets[index].gender = normalizedPet.gender
        }

        _ = profileRepository.save(
            id: current.id,
            name: current.name,
            profile: current.profile,
            profileMessage: normalizedProfileMessage,
            pet: pets,
            createdAt: current.createdAt,
            selectedPetId: targetPetId
        )

        if let targetPetId {
            profileRepository.setSelectedPetId(targetPetId, source: "profile_edit_save")
        } else {
            NotificationCenter.default.post(name: UserdefaultSetting.selectedPetDidChangeNotification, object: nil)
        }
        reloadUserInfo()
        return .success(())
    }

    /// 프로필 편집 입력값(이름/문구/반려견 정보/선택 이미지)을 저장합니다.
    /// - Parameters:
    ///   - profileName: 사용자 표시 이름 입력값입니다.
    ///   - profileMessage: 사용자 프로필 메시지 입력값입니다.
    ///   - petName: 선택 반려견의 이름 입력값입니다.
    ///   - breed: 선택 반려견의 견종 입력값입니다.
    ///   - ageYearsText: 선택 반려견의 나이 입력값(문자열)입니다.
    ///   - gender: 선택 반려견 성별 입력값입니다.
    ///   - userProfileImage: 사용자가 새로 선택한 프로필 이미지입니다.
    ///   - petProfileImage: 선택 반려견의 새 프로필 이미지입니다.
    /// - Returns: 저장 성공/실패 결과입니다.
    @MainActor
    func updateProfileDetails(
        profileName: String,
        profileMessage: String,
        petName: String,
        breed: String,
        ageYearsText: String,
        gender: PetGender,
        userProfileImage: UIImage?,
        petProfileImage: UIImage?
    ) async -> Result<Void, Error> {
        let validatedUserDraft: ValidatedUserProfileDraft
        let validatedPetDraft: ValidatedPetProfileDraft
        do {
            validatedUserDraft = try UserProfileDraft(
                displayName: profileName,
                profileMessage: profileMessage
            ).validated()
            validatedPetDraft = try PetProfileDraft(
                petName: petName,
                breed: breed,
                ageYearsText: ageYearsText,
                gender: gender
            ).validated()
        } catch let error as ProfileEditorValidationError {
            switch error {
            case .invalidAgeRange:
                return .failure(ProfileEditValidationError.invalidAgeRange)
            case .invalidDisplayName:
                return .failure(ProfileEditValidationError.invalidDisplayName)
            case .invalidPetName:
                return .failure(ProfileEditValidationError.invalidPetName)
            }
        } catch {
            return .failure(error)
        }

        guard let current = currentEditableUserInfo(
            fallbackDisplayName: validatedUserDraft.displayName,
            fallbackProfileMessage: validatedUserDraft.profileMessage
        ) else {
            return .failure(ProfileEditValidationError.userNotFound)
        }

        var pets = current.pet
        let targetPetId = selectedPetId.isEmpty == false ? selectedPetId : pets.first(where: \.isActive)?.petId
        let targetPetIndex = targetPetId.flatMap { petId in
            pets.firstIndex(where: { $0.petId == petId })
        }
        if let targetPetIndex {
            pets[targetPetIndex].petName = validatedPetDraft.petName
            pets[targetPetIndex].breed = validatedPetDraft.breed
            pets[targetPetIndex].ageYears = validatedPetDraft.ageYears
            pets[targetPetIndex].gender = validatedPetDraft.gender
        } else {
            return .failure(ProfileEditValidationError.selectedPetNotFound)
        }

        var updatedUserProfileURL = current.profile
        do {
            if let userProfileImage {
                guard let imageData = compressedJPEGData(for: userProfileImage) else {
                    return .failure(ProfileEditValidationError.imageEncodingFailed)
                }
                updatedUserProfileURL = try await imageRepository.uploadUserProfileImage(
                    data: imageData,
                    ownerId: current.id
                )
            }

            if let petProfileImage {
                guard let targetPetIndex else {
                    return .failure(ProfileEditValidationError.selectedPetNotFound)
                }
                guard let imageData = compressedJPEGData(for: petProfileImage) else {
                    return .failure(ProfileEditValidationError.imageEncodingFailed)
                }
                let uploadedPetProfileURL = try await imageRepository.uploadPetProfileImage(
                    data: imageData,
                    ownerId: current.id
                )
                pets[targetPetIndex].petProfile = uploadedPetProfileURL
            }
        } catch {
            return .failure(error)
        }

        _ = profileRepository.save(
            id: current.id,
            name: validatedUserDraft.displayName,
            profile: updatedUserProfileURL,
            profileMessage: validatedUserDraft.profileMessage,
            pet: pets,
            createdAt: current.createdAt,
            selectedPetId: targetPetId
        )
        if let targetPetId {
            profileRepository.setSelectedPetId(targetPetId, source: "profile_edit_save")
        } else {
            NotificationCenter.default.post(name: UserdefaultSetting.selectedPetDidChangeNotification, object: nil)
        }
        reloadUserInfo()
        return .success(())
    }

    /// 현재 로그인 사용자의 회원탈퇴를 요청합니다.
    /// - Returns: 탈퇴 처리 성공/실패 결과입니다.
    @MainActor
    func deleteAccount() async -> Result<Void, Error> {
        isAccountDeletionInProgress = true
        defer { isAccountDeletionInProgress = false }
        do {
            try await accountDeletionService.deleteCurrentAccount()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// 프로필 편집 화면에서 선택된 반려견의 캐리커처를 생성/재생성합니다.
    @MainActor
    func regenerateSelectedPetCaricature() async -> String {
        guard featureFlags.isEnabled(.caricatureAsyncV1) else {
            return "캐리커처 기능이 아직 비활성화되어 있어요."
        }
        guard AppFeatureGate.isAllowed(.aiGeneration, session: AppFeatureGate.currentSession()) else {
            return "회원 전용 기능입니다. 로그인 후 다시 시도해주세요."
        }
        guard let currentUser = profileRepository.fetchUserInfo(),
              let targetPet = profileRepository.selectedPet(from: currentUser) else {
            return "반려견 정보를 찾을 수 없어 캐리커처를 생성할 수 없습니다."
        }
        guard let sourceImageURL = targetPet.petProfile ?? targetPet.caricatureURL,
              sourceImageURL.isEmpty == false else {
            return "선택된 반려견 사진이 없어 캐리커처를 생성할 수 없습니다."
        }

        isCaricatureGenerating = true
        UserdefaultSetting.shared.updateFirstPetCaricature(status: .processing)
        reloadUserInfo()
        defer { isCaricatureGenerating = false }

        do {
            let response = try await caricatureClient.requestCaricature(
                petId: targetPet.petId,
                userId: currentUser.id,
                sourceImageURL: sourceImageURL,
                requestId: UUID().uuidString.lowercased()
            )
            guard let caricatureURL = response.caricatureURL,
                  caricatureURL.isEmpty == false else {
                throw CaricatureEdgeClient.RequestError.invalidResponse
            }
            UserdefaultSetting.shared.updateFirstPetCaricature(
                status: .ready,
                caricatureURL: caricatureURL,
                provider: response.provider
            )
            reloadUserInfo()
            metricTracker.track(
                .caricatureSuccess,
                userKey: currentUser.id,
                featureKey: .caricatureAsyncV1,
                payload: ["provider": response.provider ?? "unknown"]
            )
            return "캐리커처 생성이 완료되어 프로필에 반영됐어요."
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            UserdefaultSetting.shared.updateFirstPetCaricature(status: .failed)
            reloadUserInfo()
            metricTracker.track(
                .caricatureFailed,
                userKey: currentUser.id,
                featureKey: .caricatureAsyncV1,
                payload: ["error": message]
            )
            return "캐리커처 생성에 실패했습니다: \(message)"
        }
    }

    /// 설정 화면에서 표시할 반려견 상세 요약 문구를 생성합니다.
    /// - Parameter pet: 요약 문자열을 만들 반려견 정보입니다.
    /// - Returns: 견종, 나이, 성별, 활성 상태를 결합한 설명 문자열입니다.
    func petDetailsText(for pet: PetInfo) -> String {
        let breed = pet.breed.flatMap { $0.isEmpty ? nil : $0 } ?? "견종(선택) 미입력"
        let age = pet.ageYears.map { "\($0)세" } ?? "나이 미입력"
        let gender = pet.gender.title
        let activity = pet.isActive ? "활성" : "비활성"
        return "\(breed) · \(age) · \(gender) · \(activity)"
    }

    /// 새 반려견을 추가하고 즉시 화면 상태를 갱신합니다.
    /// - Parameters:
    ///   - petName: 새 반려견 이름 입력값입니다.
    ///   - breed: 새 반려견 견종 입력값입니다.
    ///   - ageYearsText: 새 반려견 나이 입력값입니다.
    ///   - gender: 새 반려견 성별 입력값입니다.
    ///   - petProfileImage: 새 반려견 프로필 이미지입니다.
    /// - Returns: 저장 성공/실패 결과입니다.
    @MainActor
    func addPet(
        petName: String,
        breed: String,
        ageYearsText: String,
        gender: PetGender,
        petProfileImage: UIImage?
    ) async -> Result<Void, Error> {
        guard let current = currentEditableUserInfo(
            fallbackDisplayName: userInfo?.name ?? "산책꾼",
            fallbackProfileMessage: userInfo?.profileMessage
        ) else {
            return .failure(ProfileEditValidationError.userNotFound)
        }
        let imageData: Data?
        if let petProfileImage {
            guard let encoded = compressedJPEGData(for: petProfileImage) else {
                return .failure(ProfileEditValidationError.imageEncodingFailed)
            }
            imageData = encoded
        } else {
            imageData = nil
        }

        do {
            _ = try await petManagementService.addPet(
                draft: PetProfileDraft(
                    petName: petName,
                    breed: breed,
                    ageYearsText: ageYearsText,
                    gender: gender
                ),
                imageData: imageData,
                currentUser: current
            )
            reloadUserInfo()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// 대표 반려견을 변경하고 즉시 화면 상태를 갱신합니다.
    /// - Parameter petId: 대표로 지정할 반려견 식별자입니다.
    func setPrimaryPet(_ petId: String) throws {
        guard let current = userInfo else {
            throw ProfileEditValidationError.userNotFound
        }
        _ = try petManagementService.setPrimaryPet(petId: petId, currentUser: current)
        reloadUserInfo()
    }

    /// 반려견 활성 상태를 변경하고 즉시 화면 상태를 갱신합니다.
    /// - Parameters:
    ///   - petId: 활성 상태를 변경할 반려견 식별자입니다.
    ///   - isActive: 적용할 활성 상태입니다.
    func setPetActive(_ petId: String, isActive: Bool) throws {
        guard let current = userInfo else {
            throw ProfileEditValidationError.userNotFound
        }
        do {
            _ = try petManagementService.setPetActive(petId: petId, isActive: isActive, currentUser: current)
            reloadUserInfo()
        } catch let error as SettingsPetManagementError {
            switch error {
            case .cannotDeactivateLastActivePet:
                throw ProfileEditValidationError.cannotDeactivateLastActivePet
            case .imageEncodingFailed:
                throw ProfileEditValidationError.imageEncodingFailed
            case .petNotFound:
                throw ProfileEditValidationError.selectedPetNotFound
            case .userNotFound:
                throw ProfileEditValidationError.userNotFound
            }
        }
    }

    /// 업로드 전 프로필 이미지를 JPEG 데이터로 압축합니다.
    /// - Parameter image: 서버 업로드 대상으로 선택된 원본 이미지입니다.
    /// - Returns: 인코딩 성공 시 JPEG 데이터, 실패 시 `nil`입니다.
    private func compressedJPEGData(for image: UIImage) -> Data? {
        image.jpegData(compressionQuality: 0.35)
    }

    /// 저장 시점에 편집 가능한 사용자 스냅샷을 조회하고, 누락 시 인증 세션 기반으로 최소 스냅샷을 복구합니다.
    /// - Parameters:
    ///   - fallbackDisplayName: 로컬 스냅샷이 없을 때 사용할 표시 이름입니다.
    ///   - fallbackProfileMessage: 로컬 스냅샷이 없을 때 사용할 프로필 메시지입니다.
    /// - Returns: 저장 가능한 사용자 스냅샷이며, 복구 불가 시 `nil`입니다.
    private func currentEditableUserInfo(
        fallbackDisplayName: String,
        fallbackProfileMessage: String?
    ) -> UserInfo? {
        if let current = profileRepository.fetchUserInfo() {
            return current
        }
        reloadUserInfo()
        if let current = profileRepository.fetchUserInfo() {
            return current
        }
        guard let identity = authSessionStore.currentIdentity(),
              identity.userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }

        let selectedPetSnapshot = selectedPet ?? profileRepository.selectedPet(from: userInfo)
        let recoveredPets: [PetInfo]
        if let selectedPetSnapshot {
            recoveredPets = [selectedPetSnapshot]
        } else {
            recoveredPets = [PetInfo(petName: "강아지", petProfile: nil, isActive: true)]
        }
        let recoveredSelectedPetId = selectedPetId.isEmpty == false
        ? selectedPetId
        : recoveredPets.first?.petId
        return UserInfo(
            id: identity.userId,
            name: fallbackDisplayName,
            profile: nil,
            profileMessage: fallbackProfileMessage,
            pet: recoveredPets,
            selectedPetId: recoveredSelectedPetId,
            createdAt: Date().timeIntervalSince1970
        )
    }

    private func bindSelectedPetSync() {
        NotificationCenter.default.publisher(for: UserdefaultSetting.selectedPetDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadUserInfo()
            }
            .store(in: &cancellables)
    }

    /// 인증 세션 변경 알림을 구독해 설정 화면 상태를 현재 세션과 즉시 동기화합니다.
    private func bindAuthSessionSync() {
        NotificationCenter.default.publisher(for: .authSessionDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleAuthSessionDidChange()
            }
            .store(in: &cancellables)
    }

    /// 세션 유효성에 따라 설정 화면 캐시를 갱신/정리합니다.
    private func handleAuthSessionDidChange() {
        guard authSessionStore.currentTokenSession() != nil else {
            userInfo = nil
            selectedPet = nil
            selectedPetId = ""
            seasonProfileSummary = nil
            return
        }
        reloadUserInfo()
    }

    private func reloadSeasonProfileSummary() {
        struct StoredSeasonState: Decodable {
            let weekKey: String
            let score: Double
            let contributionCount: Int
        }

        guard let data = UserDefaults.standard.data(forKey: "season.motion.current.v1"),
              let decoded = try? JSONDecoder().decode(StoredSeasonState.self, from: data) else {
            seasonProfileSummary = nil
            return
        }
        let score = Int(decoded.score.rounded())
        let rankTier: SeasonRankTier
        if decoded.score >= SeasonRankTier.platinum.minimumScore {
            rankTier = .platinum
        } else if decoded.score >= SeasonRankTier.gold.minimumScore {
            rankTier = .gold
        } else if decoded.score >= SeasonRankTier.silver.minimumScore {
            rankTier = .silver
        } else if decoded.score >= SeasonRankTier.bronze.minimumScore {
            rankTier = .bronze
        } else {
            rankTier = .rookie
        }
        seasonProfileSummary = SeasonProfileSummary(
            weekKey: decoded.weekKey,
            score: score,
            rankTier: rankTier,
            contributionCount: decoded.contributionCount
        )
    }
}
