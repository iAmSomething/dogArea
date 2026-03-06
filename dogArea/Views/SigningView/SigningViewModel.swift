//
//  SigningViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import Foundation
import SwiftUI

class SigningViewModel: ObservableObject {
    @Published var loading: LoadingPhase = .initial
    @Published var userName: String = ""
    @Published var userProfileMessage: String = ""
    @Published var petName: String = ""
    @Published var petBreed: String = ""
    @Published var petAgeYearsText: String = ""
    @Published var petGender: PetGender = .unknown
    @Published var userProfile: UIImage? = nil
    @Published var petProfile: UIImage? = nil
    var appleInfo: AuthUserInfo
    private var userId:String = ""
    private var petURL: String? = nil
    private var profileURL: String? = nil
    private var createdAt: Double
    private let profileRepository: ProfileRepository
    private let imageRepository: ProfileImageRepository
    private let featureFlags = FeatureFlagStore.shared
    private let metricTracker = AppMetricTracker.shared
    init(
        info: AuthUserInfo,
        profileRepository: ProfileRepository = DefaultProfileRepository.shared,
        imageRepository: ProfileImageRepository = SupabaseProfileImageRepository.shared
    ) {
        self.appleInfo = info
        self.userName = info.name ?? ""
        self.userId = info.id
        self.createdAt = info.createdAt
        self.profileRepository = profileRepository
        self.imageRepository = imageRepository
        Task {
            _ = await FeatureFlagStore.shared.refresh()
        }
    }
    func setValue(){
        loading = .loading
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let validatedUserDraft = try UserProfileDraft(
                    displayName: userName,
                    profileMessage: userProfileMessage
                ).validated()
                let validatedPetDraft = try PetProfileDraft(
                    petName: petName,
                    breed: petBreed,
                    ageYearsText: petAgeYearsText,
                    gender: petGender
                ).validated()
                if let img = userProfile {
                    profileURL = try await uploadImage(img: img, isPet: false)
                }
                if let img = petProfile {
                    petURL = try await uploadImage(img: img, isPet: true)
                }
                let caricatureEnabled = featureFlags.isEnabled(.caricatureAsyncV1)
                let petInfo = PetInfo(
                    petName: validatedPetDraft.petName,
                    petProfile: petURL,
                    breed: validatedPetDraft.breed,
                    ageYears: validatedPetDraft.ageYears,
                    gender: validatedPetDraft.gender,
                    caricatureURL: nil,
                    caricatureStatus: (caricatureEnabled && petURL != nil) ? .queued : nil,
                    caricatureProvider: nil,
                    isActive: true
                )
                _ = profileRepository.save(
                    id: userId,
                    name: validatedUserDraft.displayName,
                    profile: profileURL,
                    profileMessage: validatedUserDraft.profileMessage,
                    pet: [petInfo],
                    createdAt: createdAt,
                    selectedPetId: nil
                )
                loading = .success
                if caricatureEnabled, let currentPetURL = petURL {
                    enqueueCaricatureJobIfPossible(
                        petId: petInfo.petId,
                        userId: userId,
                        petImageURL: currentPetURL
                    )
                }
            } catch {
                loading = .fail(msg: error.localizedDescription)
            }
        }
    }

    private func enqueueCaricatureJobIfPossible(
        petId: String,
        userId: String,
        petImageURL: String
    ) {
        Task(priority: .background) { [petName, petId, userId, petImageURL] in
            let client = CaricatureEdgeClient()
            UserdefaultSetting.shared.updateFirstPetCaricature(status: .processing)
            do {
                let response = try await client.requestCaricature(
                    petId: petId,
                    userId: userId,
                    sourceImageURL: petImageURL,
                    requestId: UUID().uuidString
                )
                UserdefaultSetting.shared.updateFirstPetCaricature(
                    status: .ready,
                    caricatureURL: response.caricatureURL,
                    provider: response.provider
                )
                self.metricTracker.track(
                    .caricatureSuccess,
                    userKey: userId,
                    featureKey: .caricatureAsyncV1,
                    payload: ["provider": response.provider ?? "unknown"]
                )
                print("caricature ready for user=\(userId), pet=\(petName), job=\(response.jobId)")
            } catch {
                UserdefaultSetting.shared.updateFirstPetCaricature(status: .failed)
                self.metricTracker.track(
                    .caricatureFailed,
                    userKey: userId,
                    featureKey: .caricatureAsyncV1,
                    payload: ["error": error.localizedDescription]
                )
                print("caricature failed for user=\(userId), pet=\(petName): \(error.localizedDescription)")
            }
        }
    }

    private func uploadImage(img: UIImage, isPet: Bool) async throws -> String?{
        guard let data = img.jpegData(compressionQuality: 0.3) else { return nil }
        let ownerId = userId.isEmpty ? userName : userId
        if isPet {
            return try await imageRepository.uploadPetProfileImage(data: data, ownerId: ownerId)
        }
        return try await imageRepository.uploadUserProfileImage(data: data, ownerId: ownerId)
    }

    private var normalizedProfileMessage: String? {
        let trimmed = userProfileMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
