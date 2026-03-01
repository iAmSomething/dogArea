import Foundation

/// 프로필 편집 시트가 의존하는 데이터/액션 제공 인터페이스입니다.
protocol ProfileFieldEditProviding: AnyObject {
    /// 현재 사용자 프로필 메시지를 반환합니다.
    var initialProfileMessage: String { get }
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
    ///   - profileMessage: 사용자 프로필 메시지 입력값입니다.
    ///   - breed: 선택 반려견 견종 입력값입니다.
    ///   - ageYearsText: 선택 반려견 나이 입력값(문자열)입니다.
    ///   - gender: 선택 반려견 성별 입력값입니다.
    /// - Returns: 저장 성공/실패 결과입니다.
    func saveProfileDetails(
        profileMessage: String,
        breed: String,
        ageYearsText: String,
        gender: PetGender
    ) -> Result<Void, Error>

    /// 선택 반려견 캐리커처를 생성/재생성합니다.
    /// - Returns: 사용자 노출용 처리 결과 메시지입니다.
    func regenerateSelectedPetCaricature() async -> String
}

extension SettingViewModel: ProfileFieldEditProviding {
    var initialProfileMessage: String {
        userInfo?.profileMessage ?? ""
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
    ///   - profileMessage: 사용자 프로필 메시지 입력값입니다.
    ///   - breed: 선택 반려견 견종 입력값입니다.
    ///   - ageYearsText: 선택 반려견 나이 입력값(문자열)입니다.
    ///   - gender: 선택 반려견 성별 입력값입니다.
    /// - Returns: 저장 성공/실패 결과입니다.
    func saveProfileDetails(
        profileMessage: String,
        breed: String,
        ageYearsText: String,
        gender: PetGender
    ) -> Result<Void, Error> {
        updateProfileDetails(
            profileMessage: profileMessage,
            breed: breed,
            ageYearsText: ageYearsText,
            gender: gender
        )
        .mapError { $0 as Error }
    }
}

@MainActor
final class ProfileFieldEditSheetViewModel: ObservableObject {
    @Published var profileMessage: String
    @Published var breed: String
    @Published var ageYearsText: String
    @Published var gender: PetGender
    @Published var errorMessage: String? = nil
    @Published var caricatureMessage: String? = nil
    @Published var isGeneratingCaricature: Bool = false
    @Published private(set) var caricatureStatusText: String

    private let provider: ProfileFieldEditProviding

    /// 프로필 편집 전용 뷰모델을 초기화합니다.
    /// - Parameter provider: 프로필 편집 데이터/액션을 제공하는 의존성입니다.
    init(provider: ProfileFieldEditProviding) {
        self.provider = provider
        self.profileMessage = provider.initialProfileMessage
        self.breed = provider.initialBreed
        self.ageYearsText = provider.initialAgeYearsText
        self.gender = provider.initialGender
        self.caricatureStatusText = provider.selectedPetCaricatureStatusText
    }

    /// 프로필 편집 입력값을 저장합니다.
    /// - Returns: 저장 성공 여부입니다. 실패 시 `errorMessage`가 갱신됩니다.
    @discardableResult
    func saveChanges() -> Bool {
        errorMessage = nil
        let result = provider.saveProfileDetails(
            profileMessage: profileMessage,
            breed: breed,
            ageYearsText: ageYearsText,
            gender: gender
        )

        switch result {
        case .success:
            caricatureStatusText = provider.selectedPetCaricatureStatusText
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
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
