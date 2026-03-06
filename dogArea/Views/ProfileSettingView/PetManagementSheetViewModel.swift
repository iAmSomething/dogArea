import Foundation
import SwiftUI

/// 반려견 관리 시트가 의존하는 데이터/액션 제공 인터페이스입니다.
protocol PetManagementProviding: AnyObject {
    /// 전체 반려견 목록을 반환합니다.
    var petsForManagement: [PetInfo] { get }
    /// 현재 대표 반려견 식별자를 반환합니다.
    var selectedPetIdForManagement: String { get }

    /// 반려견 상세 요약 문구를 반환합니다.
    /// - Parameter pet: 요약 문자열을 생성할 반려견 정보입니다.
    /// - Returns: 화면에 표시할 상세 요약 문자열입니다.
    func petDetailsText(for pet: PetInfo) -> String

    /// 새 반려견을 추가합니다.
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
    ) async -> Result<Void, Error>

    /// 기존 반려견 정보를 수정합니다.
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
    ) async -> Result<Void, Error>

    /// 대표 반려견을 변경합니다.
    /// - Parameter petId: 대표로 지정할 반려견 식별자입니다.
    func setPrimaryPet(_ petId: String) throws

    /// 반려견 활성 상태를 변경합니다.
    /// - Parameters:
    ///   - petId: 상태를 변경할 반려견 식별자입니다.
    ///   - isActive: 적용할 활성 상태입니다.
    func setPetActive(_ petId: String, isActive: Bool) throws
}

extension SettingViewModel: PetManagementProviding {
    var petsForManagement: [PetInfo] {
        pets
    }

    var selectedPetIdForManagement: String {
        selectedPetId
    }
}

@MainActor
final class PetManagementSheetViewModel: ObservableObject {
    @Published var newPetName: String = ""
    @Published var newBreed: String = ""
    @Published var newAgeYearsText: String = ""
    @Published var newGender: PetGender = .unknown
    @Published var newPetProfileImage: UIImage? = nil
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    @Published var isSaving: Bool = false
    @Published private(set) var activePets: [PetInfo] = []
    @Published private(set) var inactivePets: [PetInfo] = []
    @Published private(set) var selectedPetId: String = ""

    private let provider: PetManagementProviding

    /// 반려견 관리 시트 전용 뷰모델을 구성하고 초기 스냅샷을 로드합니다.
    /// - Parameter provider: 반려견 관리 데이터와 액션을 제공하는 의존성입니다.
    init(provider: PetManagementProviding) {
        self.provider = provider
        reload()
    }

    /// 현재 제공자 스냅샷으로 활성/비활성 목록과 대표 선택 상태를 다시 로드합니다.
    func reload() {
        let pets = provider.petsForManagement
        activePets = pets.filter(\.isActive)
        inactivePets = pets.filter { $0.isActive == false }
        selectedPetId = provider.selectedPetIdForManagement
    }

    /// 화면에 표시할 반려견 상세 요약 문구를 반환합니다.
    /// - Parameter pet: 요약 문구를 생성할 반려견 정보입니다.
    /// - Returns: 견종/나이/성별/활성 상태를 결합한 문자열입니다.
    func petDetailsText(for pet: PetInfo) -> String {
        provider.petDetailsText(for: pet)
    }

    /// 기존 반려견 편집 시트용 뷰모델을 생성합니다.
    /// - Parameter pet: 편집 대상으로 선택한 반려견 정보입니다.
    /// - Returns: 저장 액션이 연결된 반려견 편집 시트 뷰모델입니다.
    func makeEditViewModel(for pet: PetInfo) -> PetManagementEditPetSheetViewModel {
        PetManagementEditPetSheetViewModel(pet: pet) { [weak self] petId, petName, breed, ageYearsText, gender, petProfileImage, removeProfileImage in
            guard let self else {
                return .failure(SettingViewModel.ProfileEditValidationError.userNotFound)
            }
            let result = await provider.updatePet(
                petId: petId,
                petName: petName,
                breed: breed,
                ageYearsText: ageYearsText,
                gender: gender,
                petProfileImage: petProfileImage,
                removeProfileImage: removeProfileImage
            )
            switch result {
            case .success:
                reload()
                successMessage = "반려견 정보를 저장했어요."
            case .failure:
                break
            }
            return result
        }
    }

    /// 새 반려견 입력값을 저장하고 성공 시 추가 폼을 초기화합니다.
    /// - Returns: 없음. 처리 결과는 메시지 상태와 목록 스냅샷에 반영됩니다.
    func addPet() async {
        errorMessage = nil
        successMessage = nil
        isSaving = true
        defer { isSaving = false }

        let result = await provider.addPet(
            petName: newPetName,
            breed: newBreed,
            ageYearsText: newAgeYearsText,
            gender: newGender,
            petProfileImage: newPetProfileImage
        )

        switch result {
        case .success:
            newPetName = ""
            newBreed = ""
            newAgeYearsText = ""
            newGender = .unknown
            newPetProfileImage = nil
            reload()
            successMessage = "반려견을 추가했어요."
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    /// 대표 반려견을 변경하고 최신 목록 스냅샷을 반영합니다.
    /// - Parameter petId: 대표로 지정할 반려견 식별자입니다.
    func setPrimaryPet(_ petId: String) {
        performImmediateAction(successMessage: "대표 반려견을 변경했어요.") {
            try provider.setPrimaryPet(petId)
        }
    }

    /// 반려견 활성 상태를 변경하고 최신 목록 스냅샷을 반영합니다.
    /// - Parameters:
    ///   - petId: 상태를 변경할 반려견 식별자입니다.
    ///   - isActive: 적용할 활성 상태입니다.
    func setPetActive(_ petId: String, isActive: Bool) {
        let message = isActive ? "반려견을 다시 활성화했어요." : "반려견을 비활성 목록으로 이동했어요."
        performImmediateAction(successMessage: message) {
            try provider.setPetActive(petId, isActive: isActive)
        }
    }

    /// 즉시 실행 가능한 동기 액션을 수행하고 공통 메시지/목록 갱신을 처리합니다.
    /// - Parameters:
    ///   - successMessage: 작업 성공 시 표시할 메시지입니다.
    ///   - action: 실행할 동기 반려견 관리 액션입니다.
    private func performImmediateAction(successMessage: String, action: () throws -> Void) {
        errorMessage = nil
        self.successMessage = nil
        do {
            try action()
            reload()
            self.successMessage = successMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
