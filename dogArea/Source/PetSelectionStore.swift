import Foundation

protocol PetSelectionStoring {
    func selectedPetId() -> String?
    func setSelectedPetId(_ petId: String, source: String)
    func selectedPet(from userInfo: UserInfo?) -> PetInfo?
    func suggestedPetForWalkStart(from userInfo: UserInfo?, now: Date) -> PetInfo?
    func recentPetSelectionEvents() -> [PetSelectionEvent]
    func clearSelectionState()
}

final class PetSelectionStore: PetSelectionStoring {
    static let shared = PetSelectionStore()
    static let selectedPetDidChangeNotification = Notification.Name("userdefault.selectedPetDidChange")

    private enum Key {
        static let selectedPetId = "selectedPetId"
        static let petSelectionScoreMap = "petSelectionScoreMap"
        static let petSelectionRecentPetId = "petSelectionRecentPetId"
        static let petSelectionEvents = "petSelectionEvents"
    }

    private enum PetSelectionTimeSlot: String {
        case morning
        case afternoon
        case evening
        case night
    }

    private let defaults: UserDefaults
    private let profileStore: ProfileStoring

    init(
        defaults: UserDefaults = .standard,
        profileStore: ProfileStoring = ProfileStore.shared
    ) {
        self.defaults = defaults
        self.profileStore = profileStore
    }

    func selectedPetId() -> String? {
        defaults.string(forKey: Key.selectedPetId)
    }

    func setSelectedPetId(_ petId: String, source: String = "manual") {
        guard let current = profileStore.getValue(), current.pet.contains(where: { $0.petId == petId }) else {
            return
        }

        let previousId = defaults.string(forKey: Key.selectedPetId)
        defaults.setValue(petId, forKey: Key.selectedPetId)
        profileStore.save(
            id: current.id,
            name: current.name,
            profile: current.profile,
            profileMessage: current.profileMessage,
            pet: current.pet,
            createdAt: current.createdAt,
            selectedPetId: petId
        )
        recordPetSelectionEvent(petId: petId, source: source)

        if previousId != petId {
            let now = Date()
            let weekday = Calendar.current.component(.weekday, from: now)
            let timeSlot = petSelectionTimeSlot(for: now).rawValue
            AppMetricTracker.shared.track(
                .petSelectionChanged,
                userKey: current.id,
                payload: [
                    "source": source,
                    "petId": petId,
                    "weekday": "\(weekday)",
                    "timeSlot": timeSlot
                ]
            )
            NotificationCenter.default.post(
                name: Self.selectedPetDidChangeNotification,
                object: nil,
                userInfo: [
                    "petId": petId,
                    "source": source
                ]
            )
        }
    }

    func selectedPet(from userInfo: UserInfo? = nil) -> PetInfo? {
        guard let info = userInfo else { return nil }
        let selectedId = selectedPetId()
        return info.pet.first(where: { $0.petId == selectedId }) ?? info.pet.first
    }

    func suggestedPetForWalkStart(from userInfo: UserInfo?, now: Date = Date()) -> PetInfo? {
        guard let info = userInfo, info.pet.isEmpty == false else { return nil }
        if info.pet.count == 1 {
            return info.pet.first
        }

        let weekday = Calendar.current.component(.weekday, from: now)
        let timeSlot = petSelectionTimeSlot(for: now)
        let scoreMap = loadPetSelectionScoreMap()
        let ranked = info.pet
            .map { pet in
                (pet, scoreMap[petSelectionScoreKey(petId: pet.petId, weekday: weekday, timeSlot: timeSlot)] ?? 0)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.petName < rhs.0.petName
                }
                return lhs.1 > rhs.1
            }

        if let first = ranked.first, first.1 > 0 {
            return first.0
        }

        if let recentPetId = defaults.string(forKey: Key.petSelectionRecentPetId),
           let recentPet = info.pet.first(where: { $0.petId == recentPetId }) {
            return recentPet
        }

        return selectedPet(from: info) ?? info.pet.first
    }

    func recentPetSelectionEvents() -> [PetSelectionEvent] {
        defaults.structArrayData(PetSelectionEvent.self, forKey: Key.petSelectionEvents)
    }

    func clearSelectionState() {
        defaults.removeObject(forKey: Key.selectedPetId)
        defaults.removeObject(forKey: Key.petSelectionScoreMap)
        defaults.removeObject(forKey: Key.petSelectionRecentPetId)
        defaults.removeObject(forKey: Key.petSelectionEvents)
    }

    private func petSelectionTimeSlot(for date: Date) -> PetSelectionTimeSlot {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5...10: return .morning
        case 11...16: return .afternoon
        case 17...21: return .evening
        default: return .night
        }
    }

    private func petSelectionScoreKey(petId: String, weekday: Int, timeSlot: PetSelectionTimeSlot) -> String {
        "\(weekday)|\(timeSlot.rawValue)|\(petId)"
    }

    private func loadPetSelectionScoreMap() -> [String: Int] {
        defaults.dictionary(forKey: Key.petSelectionScoreMap) as? [String: Int] ?? [:]
    }

    private func savePetSelectionScoreMap(_ map: [String: Int]) {
        defaults.set(map, forKey: Key.petSelectionScoreMap)
    }

    private func recordPetSelectionEvent(petId: String, source: String, at date: Date = Date()) {
        let weekday = Calendar.current.component(.weekday, from: date)
        let timeSlot = petSelectionTimeSlot(for: date)
        let key = petSelectionScoreKey(petId: petId, weekday: weekday, timeSlot: timeSlot)

        var scoreMap = loadPetSelectionScoreMap()
        scoreMap[key, default: 0] += 1
        savePetSelectionScoreMap(scoreMap)
        defaults.set(petId, forKey: Key.petSelectionRecentPetId)

        var events = defaults.structArrayData(PetSelectionEvent.self, forKey: Key.petSelectionEvents)
        events.append(
            PetSelectionEvent(
                petId: petId,
                source: source,
                weekday: weekday,
                timeSlot: timeSlot.rawValue,
                recordedAt: date.timeIntervalSince1970
            )
        )
        if events.count > 100 {
            events.removeFirst(events.count - 100)
        }
        defaults.setStructArray(events, forKey: Key.petSelectionEvents)
    }
}
