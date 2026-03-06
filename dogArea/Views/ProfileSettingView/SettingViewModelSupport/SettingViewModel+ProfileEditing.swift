import Foundation
import UIKit

extension SettingViewModel {
    /// 현재 실행 모드에 맞는 사용자 스냅샷을 결정합니다.
    /// - Returns: 일반 실행에서는 저장소 원본, UI 테스트 스텁 모드에서는 in-memory 반려견 스냅샷을 반환합니다.
    func resolveDisplayedUserInfo() -> UserInfo? {
        let fetchedUserInfo = profileRepository.fetchUserInfo()
        guard isUITestPetManagementStubEnabled == false else {
            if let uiTestPetManagementUserInfoOverride {
                return uiTestPetManagementUserInfoOverride
            }
            let seededUserInfo = makeUITestPetManagementUserInfo(base: fetchedUserInfo)
            uiTestPetManagementUserInfoOverride = seededUserInfo
            return seededUserInfo
        }
        uiTestPetManagementUserInfoOverride = nil
        return fetchedUserInfo
    }

    /// UI 테스트용 반려견 관리 스냅샷을 생성합니다.
    /// - Parameter base: 실제 저장소에서 읽은 사용자 스냅샷입니다.
    /// - Returns: 최소 1마리의 활성 반려견을 포함하는 테스트 전용 사용자 스냅샷입니다.
    func makeUITestPetManagementUserInfo(base: UserInfo?) -> UserInfo {
        let seededPet = makeUITestPetManagementPet(
            petId: "uitest-seeded-pet",
            petName: "UITestSeedDog",
            breed: "UITest Breed",
            ageYears: 4,
            gender: .female
        )
        return UserInfo(
            id: base?.id ?? "uitest-seeded-user",
            name: base?.name ?? "UITest User",
            profile: base?.profile,
            profileMessage: base?.profileMessage,
            pet: [seededPet],
            selectedPetId: seededPet.petId,
            createdAt: base?.createdAt ?? Date().timeIntervalSince1970
        )
    }

    /// UI 테스트용 반려견 스냅샷을 생성합니다.
    /// - Parameters:
    ///   - petId: 반려견 식별자입니다.
    ///   - petName: 화면에 노출할 반려견 이름입니다.
    ///   - breed: 화면에 노출할 견종 문자열입니다.
    ///   - ageYears: 화면에 노출할 나이 값입니다.
    ///   - gender: 화면에 노출할 성별 값입니다.
    /// - Returns: 반려견 관리 UI 테스트에서 사용하는 활성 반려견 스냅샷입니다.
    func makeUITestPetManagementPet(
        petId: String,
        petName: String,
        breed: String,
        ageYears: Int,
        gender: PetGender
    ) -> PetInfo {
        PetInfo(
            petId: petId,
            petName: petName,
            petProfile: nil,
            breed: breed,
            ageYears: ageYears,
            gender: gender,
            caricatureURL: nil,
            caricatureStatus: .ready,
            caricatureProvider: "ui-test",
            isActive: true
        )
    }

    /// 선택 반려견을 변경하고 설정 화면 상태를 다시 로드합니다.
    /// - Parameter petId: 대표 상태로 반영할 반려견 식별자입니다.
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
        if shouldStubProfileSaveForUITest() {
            return finalizeProfileSave(
                current: current,
                displayName: validatedUserDraft.displayName,
                profileURL: updatedUserProfileURL,
                profileMessage: validatedUserDraft.profileMessage,
                pets: pets,
                targetPetId: targetPetId
            )
        }

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

        return finalizeProfileSave(
            current: current,
            displayName: validatedUserDraft.displayName,
            profileURL: updatedUserProfileURL,
            profileMessage: validatedUserDraft.profileMessage,
            pets: pets,
            targetPetId: targetPetId
        )
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

    /// 저장 시점에 편집 가능한 사용자 스냅샷을 조회하고, 누락 시 인증 세션 기반으로 최소 스냅샷을 복구합니다.
    /// - Parameters:
    ///   - fallbackDisplayName: 로컬 스냅샷이 없을 때 사용할 표시 이름입니다.
    ///   - fallbackProfileMessage: 로컬 스냅샷이 없을 때 사용할 프로필 메시지입니다.
    /// - Returns: 저장 가능한 사용자 스냅샷이며, 복구 불가 시 `nil`입니다.
    func currentEditableUserInfo(
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

    /// UI 테스트에서 프로필 저장을 원격 업로드 없이 로컬 스텁으로 처리할지 여부를 반환합니다.
    /// - Returns: UI 테스트 전용 저장 스텁을 사용해야 하면 `true`입니다.
    func shouldStubProfileSaveForUITest() -> Bool {
        ProcessInfo.processInfo.arguments.contains("-UITest.ProfileSaveStubSuccess")
    }

    /// 검증을 통과한 프로필 편집 결과를 로컬 저장소와 현재 화면 상태에 반영합니다.
    /// - Parameters:
    ///   - current: 저장 기준이 되는 현재 사용자 정보입니다.
    ///   - displayName: 저장할 사용자 표시 이름입니다.
    ///   - profileURL: 저장할 사용자 프로필 이미지 URL입니다.
    ///   - profileMessage: 저장할 사용자 프로필 메시지입니다.
    ///   - pets: 저장할 반려견 목록입니다.
    ///   - targetPetId: 저장 후 선택 상태로 유지할 반려견 식별자입니다.
    /// - Returns: 로컬 저장 반영 결과입니다.
    func finalizeProfileSave(
        current: UserInfo,
        displayName: String,
        profileURL: String?,
        profileMessage: String?,
        pets: [PetInfo],
        targetPetId: String?
    ) -> Result<Void, Error> {
        _ = profileRepository.save(
            id: current.id,
            name: displayName,
            profile: profileURL,
            profileMessage: profileMessage,
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
}
