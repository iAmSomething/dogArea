import Foundation

/// 프로필 편집 입력 검증에서 공통으로 사용하는 오류 집합입니다.
enum ProfileEditorValidationError: LocalizedError, Equatable {
    case invalidDisplayName
    case invalidPetName
    case invalidAgeRange

    var errorDescription: String? {
        switch self {
        case .invalidDisplayName:
            return "사용자 이름은 비워둘 수 없습니다."
        case .invalidPetName:
            return "반려견 이름은 비워둘 수 없습니다."
        case .invalidAgeRange:
            return "나이는 0~30 사이 숫자로 입력해주세요."
        }
    }
}

/// 검증이 끝난 사용자 프로필 입력값입니다.
struct ValidatedUserProfileDraft: Equatable {
    let displayName: String
    let profileMessage: String?
}

/// 검증이 끝난 반려견 프로필 입력값입니다.
struct ValidatedPetProfileDraft: Equatable {
    let petName: String
    let breed: String?
    let ageYears: Int?
    let gender: PetGender
}

/// 사용자 프로필 편집 입력 초안입니다.
struct UserProfileDraft: Equatable {
    let displayName: String
    let profileMessage: String

    /// 사용자 프로필 초안을 정규화하고 검증합니다.
    /// - Parameter requiresDisplayName: 사용자 이름 필수 여부입니다.
    /// - Returns: 저장 가능한 정규화 결과입니다.
    func validated(requiresDisplayName: Bool = true) throws -> ValidatedUserProfileDraft {
        let normalizedDisplayName = Self.normalizeRequiredText(displayName)
        if requiresDisplayName, normalizedDisplayName == nil {
            throw ProfileEditorValidationError.invalidDisplayName
        }
        return ValidatedUserProfileDraft(
            displayName: normalizedDisplayName ?? "",
            profileMessage: Self.normalizeOptionalText(profileMessage)
        )
    }

    /// 공백만 포함된 문자열을 `nil`로 정규화합니다.
    /// - Parameter value: 정규화할 원본 문자열입니다.
    /// - Returns: 공백 제거 후 비어 있지 않은 문자열 또는 `nil`입니다.
    static func normalizeOptionalText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 필수 문자열 입력을 공백 제거 후 검증합니다.
    /// - Parameter value: 검증할 원본 문자열입니다.
    /// - Returns: 공백 제거 후 비어 있지 않으면 문자열을 반환하고, 아니면 `nil`을 반환합니다.
    static func normalizeRequiredText(_ value: String) -> String? {
        normalizeOptionalText(value)
    }
}

/// 반려견 프로필 편집 입력 초안입니다.
struct PetProfileDraft: Equatable {
    let petName: String
    let breed: String
    let ageYearsText: String
    let gender: PetGender

    /// 반려견 프로필 초안을 정규화하고 검증합니다.
    /// - Parameter requiresPetName: 반려견 이름 필수 여부입니다.
    /// - Returns: 저장 가능한 정규화 결과입니다.
    func validated(requiresPetName: Bool = true) throws -> ValidatedPetProfileDraft {
        let normalizedPetName = UserProfileDraft.normalizeRequiredText(petName)
        if requiresPetName, normalizedPetName == nil {
            throw ProfileEditorValidationError.invalidPetName
        }

        let trimmedAge = ageYearsText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAgeYears: Int?
        if trimmedAge.isEmpty {
            normalizedAgeYears = nil
        } else if let parsed = Int(trimmedAge), (0...30).contains(parsed) {
            normalizedAgeYears = parsed
        } else {
            throw ProfileEditorValidationError.invalidAgeRange
        }

        return ValidatedPetProfileDraft(
            petName: normalizedPetName ?? "",
            breed: UserProfileDraft.normalizeOptionalText(breed),
            ageYears: normalizedAgeYears,
            gender: gender
        )
    }
}
