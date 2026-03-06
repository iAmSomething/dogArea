import Foundation
import SwiftUI

@MainActor
final class PetManagementEditPetSheetViewModel: ObservableObject, Identifiable {
    let id: String

    @Published var petName: String {
        didSet {
            let normalizedName = petName.trimmingCharacters(in: .whitespacesAndNewlines)
            title = normalizedName.isEmpty ? "반려견 정보 수정" : normalizedName
        }
    }
    @Published var breed: String
    @Published var ageYearsText: String
    @Published var gender: PetGender
    @Published var petProfileImage: UIImage? {
        didSet {
            if petProfileImage != nil {
                didRequestImageRemoval = false
            }
        }
    }
    @Published var errorMessage: String? = nil
    @Published var isSaving: Bool = false
    @Published private(set) var title: String
    @Published private(set) var remoteImageURL: String?

    private var didRequestImageRemoval: Bool = false
    private let saveAction: (
        _ petId: String,
        _ petName: String,
        _ breed: String,
        _ ageYearsText: String,
        _ gender: PetGender,
        _ petProfileImage: UIImage?,
        _ removeProfileImage: Bool
    ) async -> Result<Void, Error>

    /// 기존 반려견 편집 시트 전용 뷰모델을 구성합니다.
    /// - Parameters:
    ///   - pet: 편집 대상 반려견 스냅샷입니다.
    ///   - saveAction: 저장 버튼 탭 시 실행할 비동기 저장 액션입니다.
    init(
        pet: PetInfo,
        saveAction: @escaping (
            _ petId: String,
            _ petName: String,
            _ breed: String,
            _ ageYearsText: String,
            _ gender: PetGender,
            _ petProfileImage: UIImage?,
            _ removeProfileImage: Bool
        ) async -> Result<Void, Error>
    ) {
        self.id = pet.petId
        self.petName = pet.petName
        self.breed = pet.breed ?? ""
        self.ageYearsText = pet.ageYears.map(String.init) ?? ""
        self.gender = pet.gender
        self.petProfileImage = nil
        self.title = pet.petName
        self.remoteImageURL = pet.petProfile
        self.saveAction = saveAction
    }

    /// 원격에 저장된 현재 반려견 이미지를 제거 대상으로 표시합니다.
    /// - Note: 새 로컬 이미지를 다시 선택하면 제거 요청은 자동으로 해제됩니다.
    func requestRemoveProfileImage() {
        petProfileImage = nil
        remoteImageURL = nil
        didRequestImageRemoval = true
    }

    /// 기존 반려견 편집 입력값을 저장합니다.
    /// - Returns: 저장 성공 여부입니다. 실패 시 `errorMessage`가 갱신됩니다.
    @discardableResult
    func saveChanges() async -> Bool {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let result = await saveAction(
            id,
            petName,
            breed,
            ageYearsText,
            gender,
            petProfileImage,
            didRequestImageRemoval
        )

        switch result {
        case .success:
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }
}
