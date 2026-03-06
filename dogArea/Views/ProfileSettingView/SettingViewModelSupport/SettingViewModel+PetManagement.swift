import Foundation
import UIKit

extension SettingViewModel {
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
        if isUITestPetManagementStubEnabled {
            return addUITestPetStub(
                petName: petName,
                breed: breed,
                ageYearsText: ageYearsText,
                gender: gender
            )
        }
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

    /// 기존 반려견 정보를 수정하고 즉시 화면 상태를 갱신합니다.
    /// - Parameters:
    ///   - petId: 수정 대상 반려견 식별자입니다.
    ///   - petName: 반려견 이름 입력값입니다.
    ///   - breed: 반려견 견종 입력값입니다.
    ///   - ageYearsText: 반려견 나이 입력값입니다.
    ///   - gender: 반려견 성별 입력값입니다.
    ///   - petProfileImage: 새로 선택한 반려견 프로필 이미지입니다.
    ///   - removeProfileImage: 기존 원격 이미지를 제거할지 여부입니다.
    /// - Returns: 저장 성공/실패 결과입니다.
    @MainActor
    func updatePet(
        petId: String,
        petName: String,
        breed: String,
        ageYearsText: String,
        gender: PetGender,
        petProfileImage: UIImage?,
        removeProfileImage: Bool
    ) async -> Result<Void, Error> {
        if isUITestPetManagementStubEnabled {
            return updateUITestPetStub(
                petId: petId,
                petName: petName,
                breed: breed,
                ageYearsText: ageYearsText,
                gender: gender
            )
        }
        let current = userInfo ?? profileRepository.fetchUserInfo()
        guard let current else {
            reloadUserInfo()
            guard let refreshed = userInfo ?? profileRepository.fetchUserInfo() else {
                return .failure(ProfileEditValidationError.userNotFound)
            }
            return await updatePet(
                current: refreshed,
                petId: petId,
                petName: petName,
                breed: breed,
                ageYearsText: ageYearsText,
                gender: gender,
                petProfileImage: petProfileImage,
                removeProfileImage: removeProfileImage
            )
        }

        return await updatePet(
            current: current,
            petId: petId,
            petName: petName,
            breed: breed,
            ageYearsText: ageYearsText,
            gender: gender,
            petProfileImage: petProfileImage,
            removeProfileImage: removeProfileImage
        )
    }

    /// UI 테스트 전용 새 반려견 추가 결과를 in-memory 상태에 반영합니다.
    /// - Parameters:
    ///   - petName: 새 반려견 이름 입력값입니다.
    ///   - breed: 새 반려견 견종 입력값입니다.
    ///   - ageYearsText: 새 반려견 나이 입력값입니다.
    ///   - gender: 새 반려견 성별 입력값입니다.
    /// - Returns: 입력 검증 및 상태 반영 결과입니다.
    func addUITestPetStub(
        petName: String,
        breed: String,
        ageYearsText: String,
        gender: PetGender
    ) -> Result<Void, Error> {
        do {
            let normalizedPetName = try validateRequiredName(petName, error: ProfileEditValidationError.invalidPetName)
            let ageYears = try parseAgeYears(from: ageYearsText)
            var current = uiTestPetManagementUserInfoOverride ?? makeUITestPetManagementUserInfo(base: profileRepository.fetchUserInfo())
            let newPet = makeUITestPetManagementPet(
                petId: UUID().uuidString.lowercased(),
                petName: normalizedPetName,
                breed: breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "UITest Breed" : breed.trimmingCharacters(in: .whitespacesAndNewlines),
                ageYears: ageYears ?? 1,
                gender: gender
            )
            current = UserInfo(
                id: current.id,
                name: current.name,
                profile: current.profile,
                profileMessage: current.profileMessage,
                pet: current.pet + [newPet],
                selectedPetId: newPet.petId,
                createdAt: current.createdAt
            )
            uiTestPetManagementUserInfoOverride = current
            reloadUserInfo()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// UI 테스트 전용 기존 반려견 수정 결과를 in-memory 상태에 반영합니다.
    /// - Parameters:
    ///   - petId: 수정 대상 반려견 식별자입니다.
    ///   - petName: 반려견 이름 입력값입니다.
    ///   - breed: 반려견 견종 입력값입니다.
    ///   - ageYearsText: 반려견 나이 입력값입니다.
    ///   - gender: 반려견 성별 입력값입니다.
    /// - Returns: 입력 검증 및 상태 반영 결과입니다.
    func updateUITestPetStub(
        petId: String,
        petName: String,
        breed: String,
        ageYearsText: String,
        gender: PetGender
    ) -> Result<Void, Error> {
        do {
            let normalizedPetName = try validateRequiredName(petName, error: ProfileEditValidationError.invalidPetName)
            let ageYears = try parseAgeYears(from: ageYearsText)
            var current = uiTestPetManagementUserInfoOverride ?? makeUITestPetManagementUserInfo(base: profileRepository.fetchUserInfo())
            guard current.pet.contains(where: { $0.petId == petId }) else {
                return .failure(ProfileEditValidationError.selectedPetNotFound)
            }
            current = UserInfo(
                id: current.id,
                name: current.name,
                profile: current.profile,
                profileMessage: current.profileMessage,
                pet: current.pet.map { pet in
                    guard pet.petId == petId else { return pet }
                    return PetInfo(
                        petId: pet.petId,
                        petName: normalizedPetName,
                        petProfile: pet.petProfile,
                        breed: breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : breed.trimmingCharacters(in: .whitespacesAndNewlines),
                        ageYears: ageYears,
                        gender: gender,
                        caricatureURL: pet.caricatureURL,
                        caricatureStatus: pet.caricatureStatus,
                        caricatureProvider: pet.caricatureProvider,
                        isActive: pet.isActive
                    )
                },
                selectedPetId: petId,
                createdAt: current.createdAt
            )
            uiTestPetManagementUserInfoOverride = current
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
            throw mapPetManagementError(error)
        }
    }

    /// 업로드 전 프로필 이미지를 JPEG 데이터로 압축합니다.
    /// - Parameter image: 서버 업로드 대상으로 선택된 원본 이미지입니다.
    /// - Returns: 인코딩 성공 시 JPEG 데이터, 실패 시 `nil`입니다.
    func compressedJPEGData(for image: UIImage) -> Data? {
        image.jpegData(compressionQuality: 0.35)
    }

    /// 기존 반려견 수정 요청을 서비스 계층에 위임하고 저장 결과를 현재 화면 상태에 반영합니다.
    /// - Parameters:
    ///   - current: 실제 저장 기준으로 사용할 현재 사용자 스냅샷입니다.
    ///   - petId: 수정 대상 반려견 식별자입니다.
    ///   - petName: 반려견 이름 입력값입니다.
    ///   - breed: 반려견 견종 입력값입니다.
    ///   - ageYearsText: 반려견 나이 입력값입니다.
    ///   - gender: 반려견 성별 입력값입니다.
    ///   - petProfileImage: 새로 선택한 반려견 프로필 이미지입니다.
    ///   - removeProfileImage: 기존 원격 이미지를 제거할지 여부입니다.
    /// - Returns: 저장 성공/실패 결과입니다.
    @MainActor
    func updatePet(
        current: UserInfo,
        petId: String,
        petName: String,
        breed: String,
        ageYearsText: String,
        gender: PetGender,
        petProfileImage: UIImage?,
        removeProfileImage: Bool
    ) async -> Result<Void, Error> {
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
            _ = try await petManagementService.updatePet(
                petId: petId,
                draft: PetProfileDraft(
                    petName: petName,
                    breed: breed,
                    ageYearsText: ageYearsText,
                    gender: gender
                ),
                imageData: imageData,
                removeProfileImage: removeProfileImage,
                currentUser: current
            )
            reloadUserInfo()
            return .success(())
        } catch let error as SettingsPetManagementError {
            return .failure(mapPetManagementError(error))
        } catch {
            return .failure(error)
        }
    }

    /// 필수 이름 입력값을 검증하고 trim된 문자열을 반환합니다.
    /// - Parameters:
    ///   - rawValue: 검증할 원본 문자열입니다.
    ///   - error: 입력값이 비어 있을 때 반환할 에러입니다.
    /// - Returns: 앞뒤 공백이 제거된 이름 문자열입니다.
    func validateRequiredName(
        _ rawValue: String,
        error: ProfileEditValidationError
    ) throws -> String {
        let normalizedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedValue.isEmpty == false else {
            throw error
        }
        return normalizedValue
    }

    /// 나이 입력 문자열을 `Int?`로 해석하고 허용 범위를 검증합니다.
    /// - Parameter value: 사용자가 입력한 나이 문자열입니다.
    /// - Returns: 빈 문자열이면 `nil`, 숫자면 0~30 범위의 정수 값을 반환합니다.
    func parseAgeYears(from value: String) throws -> Int? {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedValue.isEmpty == false else {
            return nil
        }
        guard let ageYears = Int(normalizedValue), (0...30).contains(ageYears) else {
            throw ProfileEditValidationError.invalidAgeRange
        }
        return ageYears
    }

    /// 반려견 관리 서비스 에러를 설정 화면 검증 에러로 매핑합니다.
    /// - Parameter error: 서비스 계층에서 전달된 반려견 관리 에러입니다.
    /// - Returns: 설정 화면에서 그대로 표시할 수 있는 에러입니다.
    func mapPetManagementError(_ error: SettingsPetManagementError) -> ProfileEditValidationError {
        switch error {
        case .cannotDeactivateLastActivePet:
            return .cannotDeactivateLastActivePet
        case .imageEncodingFailed:
            return .imageEncodingFailed
        case .petNotFound:
            return .selectedPetNotFound
        case .userNotFound:
            return .userNotFound
        }
    }
}
