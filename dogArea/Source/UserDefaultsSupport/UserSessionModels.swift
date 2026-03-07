import Foundation

struct UserInfo: TimeCheckable {
    let id: String
    let name: String
    let profile: String?
    let profileMessage: String?
    let pet: [PetInfo]
    var selectedPetId: String?
    var createdAt: TimeInterval
    var selectedPet: PetInfo? {
        let activePets = pet.filter(\.isActive)
        guard activePets.isEmpty == false else { return pet.first }
        guard let selectedPetId = selectedPetId else { return activePets.first }
        return activePets.first(where: { $0.id == selectedPetId }) ?? activePets.first
    }
}

enum PetGender: String, Codable, CaseIterable {
    case unknown
    case male
    case female

    var title: String {
        switch self {
        case .unknown: return "미지정"
        case .male: return "수컷"
        case .female: return "암컷"
        }
    }
}

enum CaricatureStatus: String, Codable {
    case queued
    case processing
    case ready
    case failed
}

enum SeasonCatchupBuffDisplayStatus: String, Codable {
    case active
    case granted
    case blocked
    case inactive
}

struct SeasonCatchupBuffSnapshot: Codable, Equatable {
    let walkSessionId: String
    let status: SeasonCatchupBuffDisplayStatus
    let isActive: Bool
    let bonusScore: Double
    let uiReason: String?
    let blockReason: String?
    let grantedAt: TimeInterval?
    let expiresAt: TimeInterval?
    let syncedAt: TimeInterval
}

struct PetInfo: Codable, Identifiable, Equatable {
    var id: String { petId }
    var petId: String
    var petName: String
    var petProfile: String?
    var breed: String? = nil
    var ageYears: Int? = nil
    var gender: PetGender = .unknown
    var caricatureURL: String? = nil
    var caricatureStatus: CaricatureStatus? = nil
    var caricatureProvider: String? = nil
    var isActive: Bool = true

    init(
        petId: String = UUID().uuidString.lowercased(),
        petName: String,
        petProfile: String?,
        breed: String? = nil,
        ageYears: Int? = nil,
        gender: PetGender = .unknown,
        caricatureURL: String? = nil,
        caricatureStatus: CaricatureStatus? = nil,
        caricatureProvider: String? = nil,
        isActive: Bool = true
    ) {
        self.petId = petId
        self.petName = petName
        self.petProfile = petProfile
        self.breed = breed
        self.ageYears = ageYears
        self.gender = gender
        self.caricatureURL = caricatureURL
        self.caricatureStatus = caricatureStatus
        self.caricatureProvider = caricatureProvider
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case petId
        case petName
        case petProfile
        case breed
        case ageYears
        case gender
        case caricatureURL
        case caricatureStatus
        case caricatureProvider
        case isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.petId = try container.decodeIfPresent(String.self, forKey: .petId) ?? UUID().uuidString.lowercased()
        self.petName = try container.decode(String.self, forKey: .petName)
        self.petProfile = try container.decodeIfPresent(String.self, forKey: .petProfile)
        self.breed = try container.decodeIfPresent(String.self, forKey: .breed)
        self.ageYears = try container.decodeIfPresent(Int.self, forKey: .ageYears)
        let genderRaw = try container.decodeIfPresent(String.self, forKey: .gender)
        self.gender = PetGender(rawValue: genderRaw ?? "") ?? .unknown
        self.caricatureURL = try container.decodeIfPresent(String.self, forKey: .caricatureURL)
        self.caricatureStatus = try container.decodeIfPresent(CaricatureStatus.self, forKey: .caricatureStatus)
        self.caricatureProvider = try container.decodeIfPresent(String.self, forKey: .caricatureProvider)
        self.isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
    }
}

struct PetSelectionEvent: Codable, Equatable {
    let petId: String
    let source: String
    let weekday: Int
    let timeSlot: String
    let recordedAt: TimeInterval
}
