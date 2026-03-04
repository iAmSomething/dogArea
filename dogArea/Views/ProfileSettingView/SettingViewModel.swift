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
        case selectedPetNotFound
        case imageEncodingFailed

        var errorDescription: String? {
            switch self {
            case .userNotFound:
                return "사용자 정보를 불러오지 못했습니다. 다시 로그인한 뒤 시도해주세요."
            case .invalidAgeRange:
                return "나이는 0~30 사이 숫자로 입력해주세요."
            case .invalidDisplayName:
                return "사용자 이름은 비워둘 수 없습니다."
            case .selectedPetNotFound:
                return "선택된 반려견 정보를 찾지 못했습니다."
            case .imageEncodingFailed:
                return "이미지 처리에 실패했습니다. 다른 사진으로 다시 시도해주세요."
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

    init(
        profileRepository: ProfileRepository = DefaultProfileRepository.shared,
        imageRepository: ProfileImageRepository = SupabaseProfileImageRepository.shared,
        accountDeletionService: AccountDeletionServiceProtocol = SupabaseAccountDeletionService.shared,
        authSessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared,
        walkRepository: WalkRepositoryProtocol = WalkRepositoryContainer.shared
    ) {
        self.profileRepository = profileRepository
        self.imageRepository = imageRepository
        self.accountDeletionService = accountDeletionService
        self.authSessionStore = authSessionStore
        self.walkRepository = walkRepository
        bindSelectedPetSync()
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
        reloadSeasonProfileSummary()
    }

    func selectPet(_ petId: String) {
        guard pets.contains(where: { $0.petId == petId }) else { return }
        profileRepository.setSelectedPetId(petId, source: "setting")
        reloadUserInfo()
    }

    func updateProfileDetails(
        profileMessage: String,
        breed: String,
        ageYearsText: String,
        gender: PetGender
    ) -> Result<Void, ProfileEditValidationError> {
        guard let current = profileRepository.fetchUserInfo() else {
            return .failure(.userNotFound)
        }

        let normalizedProfileMessage = normalizeOptionalText(profileMessage)
        let normalizedBreed = normalizeOptionalText(breed)
        let normalizedAgeYears: Int?

        let trimmedAge = ageYearsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAge.isEmpty {
            normalizedAgeYears = nil
        } else if let parsed = Int(trimmedAge), (0...30).contains(parsed) {
            normalizedAgeYears = parsed
        } else {
            return .failure(.invalidAgeRange)
        }

        var pets = current.pet
        let targetPetId = selectedPetId.isEmpty == false ? selectedPetId : pets.first?.petId
        if let targetPetId,
           let index = pets.firstIndex(where: { $0.petId == targetPetId }) {
            pets[index].breed = normalizedBreed
            pets[index].ageYears = normalizedAgeYears
            pets[index].gender = gender
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
        breed: String,
        ageYearsText: String,
        gender: PetGender,
        userProfileImage: UIImage?,
        petProfileImage: UIImage?
    ) async -> Result<Void, Error> {
        let normalizedProfileName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedProfileName.isEmpty == false else {
            return .failure(ProfileEditValidationError.invalidDisplayName)
        }

        let normalizedProfileMessage = normalizeOptionalText(profileMessage)
        let normalizedBreed = normalizeOptionalText(breed)
        let normalizedAgeYears: Int?
        let trimmedAge = ageYearsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAge.isEmpty {
            normalizedAgeYears = nil
        } else if let parsed = Int(trimmedAge), (0...30).contains(parsed) {
            normalizedAgeYears = parsed
        } else {
            return .failure(ProfileEditValidationError.invalidAgeRange)
        }

        guard let current = currentEditableUserInfo(
            fallbackDisplayName: normalizedProfileName,
            fallbackProfileMessage: normalizedProfileMessage
        ) else {
            return .failure(ProfileEditValidationError.userNotFound)
        }

        var pets = current.pet
        let targetPetId = selectedPetId.isEmpty == false ? selectedPetId : pets.first?.petId
        let targetPetIndex = targetPetId.flatMap { petId in
            pets.firstIndex(where: { $0.petId == petId })
        }
        if let targetPetIndex {
            pets[targetPetIndex].breed = normalizedBreed
            pets[targetPetIndex].ageYears = normalizedAgeYears
            pets[targetPetIndex].gender = gender
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
            name: normalizedProfileName,
            profile: updatedUserProfileURL,
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

    private func normalizeOptionalText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
            recoveredPets = [PetInfo(petName: "강아지", petProfile: nil)]
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
