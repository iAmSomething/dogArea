//
//  SettingViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/13/23.
//

import Foundation
import Combine

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

        var errorDescription: String? {
            switch self {
            case .userNotFound:
                return "사용자 정보를 불러오지 못했습니다."
            case .invalidAgeRange:
                return "나이는 0~30 사이 숫자로 입력해주세요."
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
    private let profileRepository: ProfileRepository
    private let walkRepository: WalkRepositoryProtocol
    private var cancellables: Set<AnyCancellable> = []

    var pets: [PetInfo] {
        userInfo?.pet ?? []
    }

    init(
        profileRepository: ProfileRepository = DefaultProfileRepository.shared,
        walkRepository: WalkRepositoryProtocol = WalkRepositoryContainer.shared
    ) {
        self.profileRepository = profileRepository
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

    private func normalizeOptionalText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
