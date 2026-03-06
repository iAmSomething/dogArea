import Foundation
import SwiftUI

/// 프로필 편집 시트가 의존하는 데이터/액션 제공 인터페이스입니다.
protocol ProfileFieldEditProviding: AnyObject {
    /// 현재 사용자 표시 이름을 반환합니다.
    var initialUserName: String { get }
    /// 현재 사용자 프로필 메시지를 반환합니다.
    var initialProfileMessage: String { get }
    /// 현재 사용자 프로필 이미지 URL을 반환합니다.
    var initialUserProfileImageURL: String? { get }
    /// 현재 선택 반려견 프로필 이미지 URL을 반환합니다.
    var initialPetProfileImageURL: String? { get }
    /// 현재 선택 반려견 이름을 반환합니다.
    var selectedPetName: String { get }
    /// 현재 선택 반려견의 이름 입력값을 반환합니다.
    var initialPetName: String { get }
    /// 현재 선택 반려견의 견종 텍스트를 반환합니다.
    var initialBreed: String { get }
    /// 현재 선택 반려견의 나이 텍스트를 반환합니다.
    var initialAgeYearsText: String { get }
    /// 현재 선택 반려견의 성별을 반환합니다.
    var initialGender: PetGender { get }
    /// 현재 선택 반려견의 캐리커처 상태 텍스트를 반환합니다.
    var selectedPetCaricatureStatusText: String { get }

    /// 사용자/반려견 프로필 편집 내용을 저장합니다.
    /// - Parameters:
    ///   - profileName: 사용자 표시 이름 입력값입니다.
    ///   - profileMessage: 사용자 프로필 메시지 입력값입니다.
    ///   - petName: 선택 반려견 이름 입력값입니다.
    ///   - breed: 선택 반려견 견종 입력값입니다.
    ///   - ageYearsText: 선택 반려견 나이 입력값(문자열)입니다.
    ///   - gender: 선택 반려견 성별 입력값입니다.
    ///   - userProfileImage: 사용자가 새로 선택한 프로필 이미지입니다.
    ///   - petProfileImage: 사용자가 새로 선택한 반려견 프로필 이미지입니다.
    /// - Returns: 저장 성공/실패 결과입니다.
    func saveProfileDetails(
        profileName: String,
        profileMessage: String,
        petName: String,
        breed: String,
        ageYearsText: String,
        gender: PetGender,
        userProfileImage: UIImage?,
        petProfileImage: UIImage?
    ) async -> Result<Void, Error>

    /// 선택 반려견 캐리커처를 생성/재생성합니다.
    /// - Returns: 사용자 노출용 처리 결과 메시지입니다.
    func regenerateSelectedPetCaricature() async -> String
}

extension SettingViewModel: ProfileFieldEditProviding {
    var initialUserName: String {
        userInfo?.name ?? ""
    }

    var initialProfileMessage: String {
        userInfo?.profileMessage ?? ""
    }

    var initialUserProfileImageURL: String? {
        userInfo?.profile
    }

    var initialPetProfileImageURL: String? {
        selectedPet?.petProfile
    }

    var selectedPetName: String {
        selectedPet?.petName ?? "반려견"
    }

    var initialPetName: String {
        selectedPet?.petName ?? ""
    }

    var initialBreed: String {
        selectedPet?.breed ?? ""
    }

    var initialAgeYearsText: String {
        selectedPet?.ageYears.map(String.init) ?? ""
    }

    var initialGender: PetGender {
        selectedPet?.gender ?? .unknown
    }

    var selectedPetCaricatureStatusText: String {
        selectedPet?.caricatureStatus?.rawValue ?? "none"
    }

    /// 프로필 편집 입력값을 저장하고 에러 타입을 일반화해 반환합니다.
    /// - Parameters:
    ///   - profileName: 사용자 표시 이름 입력값입니다.
    ///   - profileMessage: 사용자 프로필 메시지 입력값입니다.
    ///   - petName: 선택 반려견 이름 입력값입니다.
    ///   - breed: 선택 반려견 견종 입력값입니다.
    ///   - ageYearsText: 선택 반려견 나이 입력값(문자열)입니다.
    ///   - gender: 선택 반려견 성별 입력값입니다.
    ///   - userProfileImage: 사용자가 새로 선택한 프로필 이미지입니다.
    ///   - petProfileImage: 사용자가 새로 선택한 반려견 프로필 이미지입니다.
    /// - Returns: 저장 성공/실패 결과입니다.
    func saveProfileDetails(
        profileName: String,
        profileMessage: String,
        petName: String,
        breed: String,
        ageYearsText: String,
        gender: PetGender,
        userProfileImage: UIImage?,
        petProfileImage: UIImage?
    ) async -> Result<Void, Error> {
        await updateProfileDetails(
            profileName: profileName,
            profileMessage: profileMessage,
            petName: petName,
            breed: breed,
            ageYearsText: ageYearsText,
            gender: gender,
            userProfileImage: userProfileImage,
            petProfileImage: petProfileImage
        )
    }
}

@MainActor
final class ProfileFieldEditSheetViewModel: ObservableObject {
    @Published var userName: String
    @Published var profileMessage: String
    @Published var petName: String
    @Published var userProfileImage: UIImage? = nil
    @Published var petProfileImage: UIImage? = nil
    @Published var breed: String
    @Published var ageYearsText: String
    @Published var gender: PetGender
    @Published var errorMessage: String? = nil
    @Published var caricatureMessage: String? = nil
    @Published var isSaving: Bool = false
    @Published var isGeneratingCaricature: Bool = false
    @Published private(set) var caricatureStatusText: String
    @Published private(set) var userProfileImageURL: String?
    @Published private(set) var petProfileImageURL: String?
    @Published private(set) var selectedPetName: String

    private let provider: ProfileFieldEditProviding

    /// 프로필 편집 전용 뷰모델을 초기화합니다.
    /// - Parameter provider: 프로필 편집 데이터/액션을 제공하는 의존성입니다.
    init(provider: ProfileFieldEditProviding) {
        self.provider = provider
        self.userName = provider.initialUserName
        self.profileMessage = provider.initialProfileMessage
        self.petName = provider.initialPetName
        self.breed = provider.initialBreed
        self.ageYearsText = provider.initialAgeYearsText
        self.gender = provider.initialGender
        self.caricatureStatusText = provider.selectedPetCaricatureStatusText
        self.userProfileImageURL = provider.initialUserProfileImageURL
        self.petProfileImageURL = provider.initialPetProfileImageURL
        self.selectedPetName = provider.selectedPetName
    }

    /// 프로필 편집 입력값을 저장합니다.
    /// - Returns: 저장 성공 여부입니다. 실패 시 `errorMessage`가 갱신됩니다.
    @discardableResult
    func saveChanges() async -> Bool {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        #if DEBUG
        print(
            "[ProfileEditSheet] save start userName=\(userName) petName=\(petName) breed=\(breed) ageYears=\(ageYearsText) gender=\(gender.rawValue)"
        )
        #endif

        let result = await provider.saveProfileDetails(
            profileName: userName,
            profileMessage: profileMessage,
            petName: petName,
            breed: breed,
            ageYearsText: ageYearsText,
            gender: gender,
            userProfileImage: userProfileImage,
            petProfileImage: petProfileImage
        )

        switch result {
        case .success:
            #if DEBUG
            print("[ProfileEditSheet] save success")
            #endif
            caricatureStatusText = provider.selectedPetCaricatureStatusText
            selectedPetName = provider.selectedPetName
            petName = provider.initialPetName
            userProfileImage = nil
            petProfileImage = nil
            userProfileImageURL = provider.initialUserProfileImageURL
            petProfileImageURL = provider.initialPetProfileImageURL
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[ProfileEditSheet] save failure error=\(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// 캐리커처 생성/재생성을 요청합니다.
    /// - Returns: 없음. 요청 결과는 `caricatureMessage`와 `caricatureStatusText`에 반영됩니다.
    func requestCaricatureRegeneration() async {
        isGeneratingCaricature = true
        caricatureMessage = nil
        defer { isGeneratingCaricature = false }

        let message = await provider.regenerateSelectedPetCaricature()
        caricatureMessage = message
        caricatureStatusText = provider.selectedPetCaricatureStatusText
    }
}
