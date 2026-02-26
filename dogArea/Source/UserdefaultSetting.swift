//
//  UserdefaultSetting.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import Foundation
import CryptoKit
import SwiftUI
import CoreData
class UserdefaultSetting {
    enum keyValue: String {
        case userId = "userId"
        case userName = "userName"
        case userProfile = "userProfile"
        case profileMessage = "profileMessage"
        case petInfo = "petInfo"
        case selectedPetId = "selectedPetId"
        case petSelectionScoreMap = "petSelectionScoreMap"
        case petSelectionRecentPetId = "petSelectionRecentPetId"
        case petSelectionEvents = "petSelectionEvents"
        case walkStartCountdownEnabled = "walkStartCountdownEnabled"
        case walkPointRecordMode = "walkPointRecordMode"
        case createdAt = "createdAt"
        case nonce = "nonce"
    }
    static var shared = UserdefaultSetting()
    static let selectedPetDidChangeNotification = Notification.Name("userdefault.selectedPetDidChange")
    func savenonce(nonce: Double) {
        UserDefaults.standard.setValue(nonce, forKey: keyValue.nonce.rawValue)
    }
    func save(
        id: String,
        name: String,
        profile: String?,
        profileMessage: String? = nil,
        pet: [PetInfo],
        createdAt: Double,
        selectedPetId: String? = nil
    ) {
        let normalizedPets = normalizePets(pet)
        let resolvedSelectedPetId = resolveSelectedPetId(
            in: normalizedPets,
            requested: selectedPetId
        )
        UserDefaults.standard.setValue(id, forKey: keyValue.userId.rawValue)
        UserDefaults.standard.setValue(name, forKey: keyValue.userName.rawValue)
        UserDefaults.standard.setValue(profile, forKey: keyValue.userProfile.rawValue)
        UserDefaults.standard.setValue(profileMessage, forKey: keyValue.profileMessage.rawValue)
        UserDefaults.standard.setStructArray(normalizedPets, forKey: keyValue.petInfo.rawValue)
        UserDefaults.standard.setValue(resolvedSelectedPetId, forKey: keyValue.selectedPetId.rawValue)
        UserDefaults.standard.setValue(resolvedSelectedPetId, forKey: keyValue.petSelectionRecentPetId.rawValue)
        UserDefaults.standard.setValue(createdAt, forKey: keyValue.createdAt.rawValue)
    }
    func getValue() -> UserInfo? {
        guard let id = UserDefaults.standard.string(forKey: keyValue.userId.rawValue) ,
              let name = UserDefaults.standard.string(forKey: keyValue.userName.rawValue)
             
               else {return nil}
        let storedPets = UserDefaults.standard.structArrayData(PetInfo.self, forKey: keyValue.petInfo.rawValue)
        let pets = normalizePets(storedPets)
        let createdAt = UserDefaults.standard.double(forKey: keyValue.createdAt.rawValue)
        let selectedPetId = resolveSelectedPetId(
            in: pets,
            requested: UserDefaults.standard.string(forKey: keyValue.selectedPetId.rawValue)
        )
        let shouldMigrate = storedPets != pets ||
        selectedPetId != UserDefaults.standard.string(forKey: keyValue.selectedPetId.rawValue)

        if shouldMigrate {
            save(
                id: id,
                name: name,
                profile: UserDefaults.standard.string(forKey: keyValue.userProfile.rawValue),
                profileMessage: UserDefaults.standard.string(forKey: keyValue.profileMessage.rawValue),
                pet: pets,
                createdAt: createdAt,
                selectedPetId: selectedPetId
            )
        }
        if let profile = UserDefaults.standard.string(forKey: keyValue.userProfile.rawValue){
            return .init(
                id: id,
                name: name,
                profile: profile,
                profileMessage: UserDefaults.standard.string(forKey: keyValue.profileMessage.rawValue),
                pet: pets,
                createdAt: createdAt
            )
        } else {
            return .init(
                id: id,
                name: name,
                profile: nil,
                profileMessage: UserDefaults.standard.string(forKey: keyValue.profileMessage.rawValue),
                pet: pets,
                createdAt: createdAt
            )
        }
    }
    #if DEBUG
    func removeAll() {
        UserDefaults.standard.removeObject(forKey: keyValue.userId.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.userName.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.userProfile.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.profileMessage.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.petInfo.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.selectedPetId.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.walkStartCountdownEnabled.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.walkPointRecordMode.rawValue)
    }
    #endif

    private func normalizePets(_ pets: [PetInfo]) -> [PetInfo] {
        var seen = Set<String>()
        return pets.map { pet in
            var normalized = pet
            if normalized.petId.isEmpty || seen.contains(normalized.petId) {
                normalized.petId = UUID().uuidString.lowercased()
            }
            seen.insert(normalized.petId)
            return normalized
        }
    }

    private func resolveSelectedPetId(in pets: [PetInfo], requested: String?) -> String? {
        guard pets.isEmpty == false else { return nil }
        if let requested, pets.contains(where: { $0.petId == requested }) {
            return requested
        }
        if let stored = UserDefaults.standard.string(forKey: keyValue.selectedPetId.rawValue),
           pets.contains(where: { $0.petId == stored }) {
            return stored
        }
        return pets.first?.petId
    }
}
struct UserInfo: TimeCheckable {
    let id: String
    let name: String
    let profile: String?
    let profileMessage: String?
    let pet: [PetInfo]
    var createdAt: TimeInterval
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

    init(
        petId: String = UUID().uuidString.lowercased(),
        petName: String,
        petProfile: String?,
        breed: String? = nil,
        ageYears: Int? = nil,
        gender: PetGender = .unknown,
        caricatureURL: String? = nil,
        caricatureStatus: CaricatureStatus? = nil,
        caricatureProvider: String? = nil
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
    }
}

struct PetSelectionEvent: Codable, Equatable {
    let petId: String
    let source: String
    let weekday: Int
    let timeSlot: String
    let recordedAt: TimeInterval
}

enum WalkSessionEndReason: String, Codable {
    case manual = "manual"
    case autoInactive = "auto_inactive"
    case autoTimeout = "auto_timeout"
}

struct WalkSessionMetadata: Codable, Equatable {
    let endReason: WalkSessionEndReason
    let endedAt: TimeInterval
    let updatedAt: TimeInterval
}

final class WalkSessionMetadataStore {
    static let shared = WalkSessionMetadataStore()

    private let storageKey = "walk.session.metadata.v1"
    private let lock = NSLock()
    private var cache: [String: WalkSessionMetadata] = [:]

    private init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: WalkSessionMetadata].self, from: data) else {
            cache = [:]
            return
        }
        cache = decoded
    }

    func set(sessionId: UUID, reason: WalkSessionEndReason, endedAt: TimeInterval) {
        lock.lock()
        cache[sessionId.uuidString.lowercased()] = WalkSessionMetadata(
            endReason: reason,
            endedAt: endedAt,
            updatedAt: Date().timeIntervalSince1970
        )
        persistLocked()
        lock.unlock()
    }

    func metadata(sessionId: UUID) -> WalkSessionMetadata? {
        lock.lock()
        defer { lock.unlock() }
        return cache[sessionId.uuidString.lowercased()]
    }

    func clear(sessionId: UUID) {
        lock.lock()
        cache.removeValue(forKey: sessionId.uuidString.lowercased())
        persistLocked()
        lock.unlock()
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

extension UserDefaults {
    public func setStruct<T: Codable>(_ value: T?, forKey defaultName: String){
        let data = try? JSONEncoder().encode(value)
        set(data, forKey: defaultName)
    }
    
    public func structData<T>(_ type: T.Type, forKey defaultName: String) -> T? where T : Decodable {
        guard let encodedData = data(forKey: defaultName) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: encodedData)
    }
    
    public func setStructArray<T: Codable>(_ value: [T], forKey defaultName: String){
        let data = value.map { try? JSONEncoder().encode($0) }
        
        set(data, forKey: defaultName)
    }
    
    public func structArrayData<T>(_ type: T.Type, forKey defaultName: String) -> [T] where T : Decodable {
        guard let encodedData = array(forKey: defaultName) as? [Data] else {
            return []
        }
        return encodedData.compactMap { try? JSONDecoder().decode(type, from: $0) }
    }
}

extension UserdefaultSetting {
    private enum PetSelectionTimeSlot: String {
        case morning
        case afternoon
        case evening
        case night
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
        UserDefaults.standard.dictionary(forKey: keyValue.petSelectionScoreMap.rawValue) as? [String: Int] ?? [:]
    }

    private func savePetSelectionScoreMap(_ map: [String: Int]) {
        UserDefaults.standard.set(map, forKey: keyValue.petSelectionScoreMap.rawValue)
    }

    private func recordPetSelectionEvent(petId: String, source: String, at date: Date = Date()) {
        let weekday = Calendar.current.component(.weekday, from: date)
        let timeSlot = petSelectionTimeSlot(for: date)
        let key = petSelectionScoreKey(petId: petId, weekday: weekday, timeSlot: timeSlot)
        var scoreMap = loadPetSelectionScoreMap()
        scoreMap[key, default: 0] += 1
        savePetSelectionScoreMap(scoreMap)
        UserDefaults.standard.set(petId, forKey: keyValue.petSelectionRecentPetId.rawValue)

        var events = UserDefaults.standard.structArrayData(PetSelectionEvent.self, forKey: keyValue.petSelectionEvents.rawValue)
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
        UserDefaults.standard.setStructArray(events, forKey: keyValue.petSelectionEvents.rawValue)
    }

    func selectedPetId() -> String? {
        UserDefaults.standard.string(forKey: keyValue.selectedPetId.rawValue)
    }

    func setSelectedPetId(_ petId: String, source: String = "manual") {
        guard let current = getValue(), current.pet.contains(where: { $0.petId == petId }) else {
            return
        }
        let previousId = UserDefaults.standard.string(forKey: keyValue.selectedPetId.rawValue)
        UserDefaults.standard.setValue(petId, forKey: keyValue.selectedPetId.rawValue)
        // Normalize persisted payload in case pet ids were migrated this session.
        save(
            id: current.id,
            name: current.name,
            profile: current.profile,
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
                name: UserdefaultSetting.selectedPetDidChangeNotification,
                object: nil,
                userInfo: [
                    "petId": petId,
                    "source": source
                ]
            )
        }
    }

    func selectedPet(from userInfo: UserInfo? = nil) -> PetInfo? {
        let info = userInfo ?? getValue()
        guard let info else { return nil }
        let selectedId = selectedPetId()
        return info.pet.first(where: { $0.petId == selectedId }) ?? info.pet.first
    }

    func suggestedPetForWalkStart(from userInfo: UserInfo? = nil, now: Date = Date()) -> PetInfo? {
        let info = userInfo ?? getValue()
        guard let info, info.pet.isEmpty == false else { return nil }
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

        if let recentPetId = UserDefaults.standard.string(forKey: keyValue.petSelectionRecentPetId.rawValue),
           let recentPet = info.pet.first(where: { $0.petId == recentPetId }) {
            return recentPet
        }

        return selectedPet(from: info) ?? info.pet.first
    }

    func recentPetSelectionEvents() -> [PetSelectionEvent] {
        UserDefaults.standard.structArrayData(PetSelectionEvent.self, forKey: keyValue.petSelectionEvents.rawValue)
    }

    func updateFirstPetCaricature(
        status: CaricatureStatus,
        caricatureURL: String? = nil,
        provider: String? = nil
    ) {
        guard let current = getValue(), current.pet.isEmpty == false else { return }
        let targetPetId = selectedPet(from: current)?.petId ?? current.pet.first?.petId
        guard let targetPetId else { return }
        var pets = current.pet
        if let index = pets.firstIndex(where: { $0.petId == targetPetId }) {
            pets[index].caricatureStatus = status
            if let caricatureURL {
                pets[index].caricatureURL = caricatureURL
                pets[index].petProfile = caricatureURL
            }
            if let provider {
                pets[index].caricatureProvider = provider
            }
        }
        save(
            id: current.id,
            name: current.name,
            profile: current.profile,
            pet: pets,
            createdAt: current.createdAt,
            selectedPetId: targetPetId
        )
    }

    func walkStartCountdownEnabled() -> Bool {
        UserDefaults.standard.object(forKey: keyValue.walkStartCountdownEnabled.rawValue) as? Bool ?? false
    }

    func setWalkStartCountdownEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: keyValue.walkStartCountdownEnabled.rawValue)
    }

    func walkPointRecordModeRawValue() -> String {
        UserDefaults.standard.string(forKey: keyValue.walkPointRecordMode.rawValue) ?? "manual"
    }

    func setWalkPointRecordModeRawValue(_ rawValue: String) {
        UserDefaults.standard.set(rawValue, forKey: keyValue.walkPointRecordMode.rawValue)
    }

}

enum AppFeatureFlagKey: String, CaseIterable {
    case heatmapV1 = "ff_heatmap_v1"
    case caricatureAsyncV1 = "ff_caricature_async_v1"
    case nearbyHotspotV1 = "ff_nearby_hotspot_v1"
}

enum AppMetricEvent: String {
    case walkSaveSuccess = "walk_save_success"
    case walkSaveFailed = "walk_save_failed"
    case watchActionReceived = "watch_action_received"
    case watchActionProcessed = "watch_action_processed"
    case watchActionApplied = "watch_action_applied"
    case watchActionDuplicate = "watch_action_duplicate"
    case caricatureSuccess = "caricature_success"
    case caricatureFailed = "caricature_failed"
    case nearbyOptInEnabled = "nearby_opt_in_enabled"
    case nearbyOptInDisabled = "nearby_opt_in_disabled"
    case petSelectionChanged = "pet_selection_changed"
    case petSelectionSuggested = "pet_selection_suggested"
}

final class FeatureFlagStore {
    static let shared = FeatureFlagStore()

    private struct FeatureFlagValue: Codable, Equatable {
        let isEnabled: Bool
        let rolloutPercent: Int
        let updatedAt: String?
    }

    private struct FeatureFlagRowDTO: Decodable {
        let key: String
        let isEnabled: Bool
        let rolloutPercent: Int
        let updatedAt: String?

        enum CodingKeys: String, CodingKey {
            case key
            case isEnabled = "is_enabled"
            case rolloutPercent = "rollout_percent"
            case updatedAt = "updated_at"
        }
    }

    private struct FeatureFlagEnvelope: Decodable {
        let flags: [FeatureFlagRowDTO]
    }

    private let lock = NSLock()
    private let cacheStorageKey = "feature.flags.cache.v1"
    private let appInstanceStorageKey = "feature.flags.appInstance.v1"
    private var cached: [String: FeatureFlagValue] = [:]
    private lazy var appInstance: String = {
        if let existing = UserDefaults.standard.string(forKey: appInstanceStorageKey), existing.isEmpty == false {
            return existing
        }
        let generated = UUID().uuidString.lowercased()
        UserDefaults.standard.set(generated, forKey: appInstanceStorageKey)
        return generated
    }()

    private let defaults: [String: FeatureFlagValue] = [
        AppFeatureFlagKey.heatmapV1.rawValue: .init(isEnabled: true, rolloutPercent: 100, updatedAt: nil),
        AppFeatureFlagKey.caricatureAsyncV1.rawValue: .init(isEnabled: true, rolloutPercent: 100, updatedAt: nil),
        AppFeatureFlagKey.nearbyHotspotV1.rawValue: .init(isEnabled: true, rolloutPercent: 100, updatedAt: nil),
    ]

    private init() {
        loadCachedFlags()
    }

    var appInstanceId: String { appInstance }

    func isEnabled(_ key: AppFeatureFlagKey) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let flag = cached[key.rawValue] ?? defaults[key.rawValue] ?? .init(isEnabled: true, rolloutPercent: 100, updatedAt: nil)
        return isEnabled(flag: flag, key: key.rawValue)
    }

    @discardableResult
    func refresh() async -> Bool {
        do {
            let data = try await FeatureControlService.shared.post(payload: [
                "action": "get_flags",
                "keys": AppFeatureFlagKey.allCases.map(\.rawValue)
            ])
            let decoded = try JSONDecoder().decode(FeatureFlagEnvelope.self, from: data)
            let newValues = Dictionary(uniqueKeysWithValues: decoded.flags.map {
                ($0.key, FeatureFlagValue(isEnabled: $0.isEnabled, rolloutPercent: $0.rolloutPercent, updatedAt: $0.updatedAt))
            })
            lock.lock()
            cached.merge(newValues) { _, latest in latest }
            persistCachedFlags()
            lock.unlock()
            return true
        } catch {
            return false
        }
    }

    private func isEnabled(flag: FeatureFlagValue, key: String) -> Bool {
        guard flag.isEnabled else { return false }
        let percent = max(0, min(100, flag.rolloutPercent))
        if percent >= 100 { return true }
        if percent <= 0 { return false }
        return rolloutBucket(for: key) < percent
    }

    private func rolloutBucket(for key: String) -> Int {
        let seed = "\(appInstance):\(key)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        guard let first = Array(digest).first else { return 0 }
        return Int(first) % 100
    }

    private func loadCachedFlags() {
        guard let data = UserDefaults.standard.data(forKey: cacheStorageKey) else {
            cached = defaults
            return
        }
        guard let decoded = try? JSONDecoder().decode([String: FeatureFlagValue].self, from: data) else {
            cached = defaults
            return
        }
        cached = defaults.merging(decoded) { _, saved in saved }
    }

    private func persistCachedFlags() {
        guard let data = try? JSONEncoder().encode(cached) else { return }
        UserDefaults.standard.set(data, forKey: cacheStorageKey)
    }
}

final class AppMetricTracker {
    static let shared = AppMetricTracker()

    private init() {}

    func track(
        _ event: AppMetricEvent,
        userKey: String? = nil,
        featureKey: AppFeatureFlagKey? = nil,
        eventValue: Double? = nil,
        payload: [String: String] = [:]
    ) {
        var body: [String: Any] = [
            "action": "track_metric",
            "eventName": event.rawValue,
            "appInstanceId": FeatureFlagStore.shared.appInstanceId
        ]
        if let userKey, userKey.isEmpty == false {
            body["userKey"] = userKey
        }
        if let featureKey {
            body["featureKey"] = featureKey.rawValue
        }
        if let eventValue {
            body["eventValue"] = eventValue
        }
        if payload.isEmpty == false {
            body["payload"] = payload
        }
        FeatureControlService.shared.postFireAndForget(payload: body)
    }
}

private struct FeatureControlService {
    static let shared = FeatureControlService()

    private enum ServiceError: Error {
        case notConfigured
        case invalidURL
        case badResponse
    }

    private func endpointURL() throws -> URL {
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["SUPABASE_URL"], raw.isEmpty == false else {
            throw ServiceError.notConfigured
        }
        guard let url = URL(string: raw + "/functions/v1/feature-control") else {
            throw ServiceError.invalidURL
        }
        return url
    }

    private func bearerToken() -> String {
        ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    }

    func post(payload: [String: Any]) async throws -> Data {
        let url = try endpointURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = bearerToken()
        if token.isEmpty == false {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let code = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(code) else {
            throw ServiceError.badResponse
        }
        return data
    }

    func postFireAndForget(payload: [String: Any]) {
        guard let url = try? endpointURL() else { return }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = bearerToken()
        if token.isEmpty == false {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        URLSession.shared.dataTask(with: request).resume()
    }
}

struct CaricatureEdgeClient {
    static let schemaVersion = "2026-02-26.v1"

    struct ResponseDTO: Decodable {
        let version: String?
        let requestId: String?
        let jobId: String
        let provider: String?
        let caricatureUrl: String?
        let status: String?
        let errorCode: String?
        let message: String?

        var caricatureURL: String? { caricatureUrl }
    }

    private struct ErrorDTO: Decodable {
        let errorCode: String?
        let message: String?
    }

    struct RequestDTO: Encodable {
        let version: String
        let petId: String
        let userId: String?
        let sourceImagePath: String?
        let sourceImageUrl: String?
        let style: String
        let providerHint: String
        let requestId: String
    }

    enum RequestError: LocalizedError {
        case notConfigured
        case invalidURL
        case invalidResponse
        case requestFailed(code: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Supabase 설정이 누락되어 캐리커처 요청을 보낼 수 없습니다."
            case .invalidURL:
                return "캐리커처 요청 URL이 올바르지 않습니다."
            case .invalidResponse:
                return "캐리커처 응답을 해석할 수 없습니다."
            case .requestFailed(_, let message):
                return message
            }
        }
    }

    func requestCaricature(
        petId: String,
        userId: String?,
        sourceImagePath: String? = nil,
        sourceImageURL: String? = nil,
        style: String = "cute_cartoon",
        providerHint: String = "auto",
        requestId: String
    ) async throws -> ResponseDTO {
        let env = ProcessInfo.processInfo.environment
        let supabaseURL = env["SUPABASE_URL"] ?? ""
        let anonKey = env["SUPABASE_ANON_KEY"] ?? ""
        guard supabaseURL.isEmpty == false, anonKey.isEmpty == false else {
            throw RequestError.notConfigured
        }
        guard let url = URL(string: "\(supabaseURL)/functions/v1/caricature") else {
            throw RequestError.invalidURL
        }

        let payload = RequestDTO(
            version: Self.schemaVersion,
            petId: petId,
            userId: userId,
            sourceImagePath: sourceImagePath,
            sourceImageUrl: sourceImageURL,
            style: style,
            providerHint: providerHint,
            requestId: requestId
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            throw RequestError.invalidResponse
        }
        guard (200..<300).contains(statusCode) else {
            if let err = try? JSONDecoder().decode(ErrorDTO.self, from: data) {
                let message = err.message ?? "캐리커처 생성에 실패했습니다. 잠시 후 다시 시도해주세요."
                throw RequestError.requestFailed(code: statusCode, message: message)
            }
            throw RequestError.requestFailed(
                code: statusCode,
                message: "캐리커처 생성 실패(\(statusCode)). 네트워크/권한을 확인해주세요."
            )
        }
        guard let decoded = try? JSONDecoder().decode(ResponseDTO.self, from: data) else {
            throw RequestError.invalidResponse
        }
        return decoded
    }
}

enum SyncOutboxStage: String, Codable, CaseIterable {
    case session
    case points
    case meta

    var order: Int {
        switch self {
        case .session: return 0
        case .points: return 1
        case .meta: return 2
        }
    }
}

enum SyncOutboxStatus: String, Codable {
    case queued
    case retrying
    case processing
    case permanentFailed
    case completed
}

enum SyncOutboxErrorCode: String, Codable {
    case offline = "offline"
    case tokenExpired = "token_expired"
    case unauthorized = "unauthorized"
    case serverError = "server_error"
    case conflict = "conflict"
    case schemaMismatch = "schema_mismatch"
    case storageQuota = "storage_quota"
    case notConfigured = "not_configured"
    case unknown = "unknown"
}

struct SyncOutboxItem: Codable, Identifiable, Equatable {
    let id: String
    let walkSessionId: String
    let stage: SyncOutboxStage
    let idempotencyKey: String
    let payload: [String: String]
    var status: SyncOutboxStatus
    var retryCount: Int
    var nextRetryAt: TimeInterval
    var lastErrorCode: SyncOutboxErrorCode?
    let createdAt: TimeInterval
    var updatedAt: TimeInterval
}

struct SyncOutboxSummary: Equatable {
    let pendingCount: Int
    let permanentFailureCount: Int
    let lastErrorCode: SyncOutboxErrorCode?
}

struct SyncBackfillValidationSummary: Codable, Equatable {
    let sessionCount: Int
    let pointCount: Int
    let totalAreaM2: Double
    let totalDurationSec: Double
}

enum SyncOutboxSendResult: Equatable {
    case success
    case retryable(SyncOutboxErrorCode)
    case permanent(SyncOutboxErrorCode)
}

protocol SyncOutboxTransporting {
    func send(item: SyncOutboxItem) async -> SyncOutboxSendResult
}

final class SyncOutboxStore {
    static let shared = SyncOutboxStore()

    private let lock = NSLock()
    private let storageKey = "sync.outbox.items.v1"
    private var items: [SyncOutboxItem] = []
    private let maxItems = 500

    private init() {
        load()
    }

    func enqueueWalkStages(sessionDTO: WalkSessionBackfillDTO) {
        let sessionId = sessionDTO.walkSessionId
        let baseKey = "walk-\(sessionId)"
        let now = Date().timeIntervalSince1970
        let basePayload: [String: String] = [
            "walk_session_id": sessionId,
            "user_id": sessionDTO.ownerUserId ?? "",
            "pet_id": sessionDTO.petId ?? "",
            "created_at": String(sessionDTO.createdAt),
            "started_at": String(sessionDTO.startedAt),
            "ended_at": String(sessionDTO.endedAt),
            "source_device": sessionDTO.sourceDevice
        ]

        let stagePayloads: [(SyncOutboxStage, [String: String])] = [
            (
                .session,
                basePayload.merging(
                    [
                        "duration_sec": String(sessionDTO.durationSec),
                        "area_m2": String(sessionDTO.areaM2),
                    ],
                    uniquingKeysWith: { _, latest in latest }
                )
            ),
            (
                .points,
                basePayload.merging(
                    [
                        "point_count": String(sessionDTO.pointCount),
                        "points_json": sessionDTO.pointsJSONString
                    ],
                    uniquingKeysWith: { _, latest in latest }
                )
            ),
            (
                .meta,
                basePayload.merging(
                    [
                        "has_image": sessionDTO.hasImage ? "true" : "false",
                        "map_image_url": sessionDTO.mapImageURL ?? ""
                    ],
                    uniquingKeysWith: { _, latest in latest }
                )
            ),
        ]

        lock.lock()
        var mutableItems = items
        stagePayloads.forEach { stage, payload in
            let idempotencyKey = "\(baseKey)-\(stage.rawValue)"
            let exists = mutableItems.contains(where: { $0.idempotencyKey == idempotencyKey })
            guard exists == false else { return }
            mutableItems.append(
                SyncOutboxItem(
                    id: UUID().uuidString.lowercased(),
                    walkSessionId: sessionId,
                    stage: stage,
                    idempotencyKey: idempotencyKey,
                    payload: payload,
                    status: .queued,
                    retryCount: 0,
                    nextRetryAt: now,
                    lastErrorCode: nil,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }
        if mutableItems.count > maxItems {
            let overflow = mutableItems.count - maxItems
            let removable = mutableItems
                .enumerated()
                .filter { _, item in item.status == .completed || item.status == .permanentFailed }
                .prefix(overflow)
                .map(\.offset)
            removable.reversed().forEach { mutableItems.remove(at: $0) }
        }
        items = mutableItems
        persistLocked()
        lock.unlock()
    }

    func summary() -> SyncOutboxSummary {
        lock.lock()
        defer { lock.unlock() }
        let pending = items.filter { $0.status == .queued || $0.status == .retrying || $0.status == .processing }.count
        let permanent = items.filter { $0.status == .permanentFailed }.count
        let lastError = items.reversed().compactMap(\.lastErrorCode).first
        return SyncOutboxSummary(pendingCount: pending, permanentFailureCount: permanent, lastErrorCode: lastError)
    }

    @discardableResult
    func flush(using transport: SyncOutboxTransporting, now: Date = Date()) async -> SyncOutboxSummary {
        let nowTs = now.timeIntervalSince1970
        while let next = nextDispatchableItem(now: nowTs) {
            updateItem(id: next.id) { item in
                item.status = .processing
                item.updatedAt = Date().timeIntervalSince1970
            }

            let result = await transport.send(item: next)
            let currentNow = Date().timeIntervalSince1970
            switch result {
            case .success:
                updateItem(id: next.id) { item in
                    item.status = .completed
                    item.lastErrorCode = nil
                    item.updatedAt = currentNow
                }
            case .retryable(let code):
                let delay = Self.retryDelay(retryCount: next.retryCount + 1)
                updateItem(id: next.id) { item in
                    item.status = .retrying
                    item.retryCount += 1
                    item.lastErrorCode = code
                    item.nextRetryAt = currentNow + delay
                    item.updatedAt = currentNow
                }
                return summary()
            case .permanent(let code):
                updateItem(id: next.id) { item in
                    item.status = .permanentFailed
                    item.lastErrorCode = code
                    item.updatedAt = currentNow
                }
                return summary()
            }
        }
        return summary()
    }

    func requeuePermanentFailures(walkSessionIds: Set<String>? = nil) {
        lock.lock()
        let now = Date().timeIntervalSince1970
        for index in items.indices {
            guard items[index].status == .permanentFailed else { continue }
            if let walkSessionIds, walkSessionIds.contains(items[index].walkSessionId) == false {
                continue
            }
            items[index].status = .retrying
            items[index].retryCount = 0
            items[index].nextRetryAt = now
            items[index].lastErrorCode = nil
            items[index].updatedAt = now
        }
        persistLocked()
        lock.unlock()
    }

    private static func retryDelay(retryCount: Int) -> TimeInterval {
        let exp = pow(2.0, Double(max(0, retryCount)))
        return min(900.0, 5.0 * exp)
    }

    private func nextDispatchableItem(now: TimeInterval) -> SyncOutboxItem? {
        lock.lock()
        defer { lock.unlock() }
        return items
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    if lhs.stage.order == rhs.stage.order {
                        return lhs.id < rhs.id
                    }
                    return lhs.stage.order < rhs.stage.order
                }
                return lhs.createdAt < rhs.createdAt
            }
            .first(where: {
                ($0.status == .queued || $0.status == .retrying || $0.status == .processing) &&
                $0.nextRetryAt <= now
            })
    }

    private func updateItem(id: String, _ block: (inout SyncOutboxItem) -> Void) {
        lock.lock()
        if let idx = items.firstIndex(where: { $0.id == id }) {
            block(&items[idx])
            persistLocked()
        }
        lock.unlock()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SyncOutboxItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

struct SupabaseSyncOutboxTransport: SyncOutboxTransporting {
    private struct BackfillSummaryResponseDTO: Decodable {
        let summary: SummaryDTO?

        struct SummaryDTO: Decodable {
            let sessionCount: Int
            let pointCount: Int
            let totalAreaM2: Double
            let totalDurationSec: Double

            enum CodingKeys: String, CodingKey {
                case sessionCount = "session_count"
                case pointCount = "point_count"
                case totalAreaM2 = "total_area_m2"
                case totalDurationSec = "total_duration_sec"
            }
        }
    }

    private func endpointURL(from env: [String: String]) -> URL? {
        guard let rawURL = env["SUPABASE_URL"], rawURL.isEmpty == false else { return nil }
        return URL(string: rawURL + "/functions/v1/sync-walk")
    }

    private func bearerToken(from env: [String: String]) -> String {
        env["SUPABASE_ANON_KEY"] ?? ""
    }

    func send(item: SyncOutboxItem) async -> SyncOutboxSendResult {
        guard AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) else {
            return .retryable(.unauthorized)
        }
        let env = ProcessInfo.processInfo.environment
        guard let url = endpointURL(from: env) else {
            return .retryable(.notConfigured)
        }

        let token = bearerToken(from: env)
        guard token.isEmpty == false else {
            return .retryable(.tokenExpired)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "action": "sync_walk_stage",
            "walk_session_id": item.walkSessionId,
            "stage": item.stage.rawValue,
            "idempotency_key": item.idempotencyKey,
            "payload": item.payload
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                return .retryable(.unknown)
            }
            switch statusCode {
            case 200..<300:
                return .success
            case 401, 403:
                return .retryable(.tokenExpired)
            case 409:
                return .success
            case 429, 500..<600:
                return .retryable(.serverError)
            case 404:
                return .retryable(.notConfigured)
            case 400, 422:
                return .permanent(.schemaMismatch)
            case 507:
                return .permanent(.storageQuota)
            default:
                return .retryable(.unknown)
            }
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .retryable(.offline)
            case .userAuthenticationRequired:
                return .retryable(.tokenExpired)
            default:
                return .retryable(.unknown)
            }
        } catch {
            return .retryable(.unknown)
        }
    }

    func fetchBackfillValidationSummary(sessionIds: [String]) async -> SyncBackfillValidationSummary? {
        guard AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) else {
            return nil
        }
        let env = ProcessInfo.processInfo.environment
        guard let url = endpointURL(from: env) else { return nil }
        let token = bearerToken(from: env)
        guard token.isEmpty == false else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "action": "get_backfill_summary",
            "session_ids": sessionIds
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode,
                  (200..<300).contains(statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(BackfillSummaryResponseDTO.self, from: data)
            guard let summary = decoded.summary else { return nil }
            return SyncBackfillValidationSummary(
                sessionCount: summary.sessionCount,
                pointCount: summary.pointCount,
                totalAreaM2: summary.totalAreaM2,
                totalDurationSec: summary.totalDurationSec
            )
        } catch {
            return nil
        }
    }
}

enum ProfileSyncOutboxStage: String, Codable, CaseIterable {
    case profile
    case pet

    var order: Int {
        switch self {
        case .profile: return 0
        case .pet: return 1
        }
    }
}

struct ProfileSyncOutboxItem: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let petId: String?
    let stage: ProfileSyncOutboxStage
    let idempotencyKey: String
    let payload: [String: String]
    var status: SyncOutboxStatus
    var retryCount: Int
    var nextRetryAt: TimeInterval
    var lastErrorCode: SyncOutboxErrorCode?
    let createdAt: TimeInterval
    var updatedAt: TimeInterval
}

protocol ProfileSyncOutboxTransporting {
    func send(item: ProfileSyncOutboxItem) async -> SyncOutboxSendResult
}

final class ProfileSyncOutboxStore {
    static let shared = ProfileSyncOutboxStore()

    private let lock = NSLock()
    private let storageKey = "sync.profile.outbox.items.v1"
    private var items: [ProfileSyncOutboxItem] = []
    private let maxItems = 500

    private init() {
        load()
    }

    func enqueueSnapshot(userInfo: UserInfo) {
        lock.lock()
        var mutable = items
        let now = Date().timeIntervalSince1970

        let profilePayload: [String: String] = [
            "display_name": userInfo.name,
            "profile_image_url": userInfo.profile ?? "",
            "profile_message": userInfo.profileMessage ?? ""
        ]
        let profileKey = "profile-\(userInfo.id)"
        if mutable.contains(where: { $0.idempotencyKey == profileKey && $0.status != .completed }) == false {
            mutable.append(
                ProfileSyncOutboxItem(
                    id: UUID().uuidString.lowercased(),
                    userId: userInfo.id,
                    petId: nil,
                    stage: .profile,
                    idempotencyKey: profileKey,
                    payload: profilePayload,
                    status: .queued,
                    retryCount: 0,
                    nextRetryAt: now,
                    lastErrorCode: nil,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        userInfo.pet.forEach { pet in
            let petKey = "pet-\(userInfo.id)-\(pet.petId)"
            guard mutable.contains(where: { $0.idempotencyKey == petKey && $0.status != .completed }) == false else {
                return
            }
            let payload: [String: String] = [
                "pet_id": pet.petId,
                "name": pet.petName,
                "photo_url": pet.petProfile ?? "",
                "breed": pet.breed ?? "",
                "age_years": pet.ageYears.map(String.init) ?? "",
                "gender": pet.gender.rawValue,
                "is_active": "true"
            ]
            mutable.append(
                ProfileSyncOutboxItem(
                    id: UUID().uuidString.lowercased(),
                    userId: userInfo.id,
                    petId: pet.petId,
                    stage: .pet,
                    idempotencyKey: petKey,
                    payload: payload,
                    status: .queued,
                    retryCount: 0,
                    nextRetryAt: now,
                    lastErrorCode: nil,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        if mutable.count > maxItems {
            let overflow = mutable.count - maxItems
            let removable = mutable
                .enumerated()
                .filter { _, item in item.status == .completed || item.status == .permanentFailed }
                .prefix(overflow)
                .map(\.offset)
            removable.reversed().forEach { mutable.remove(at: $0) }
        }

        items = mutable
        persistLocked()
        lock.unlock()
    }

    func summary() -> SyncOutboxSummary {
        lock.lock()
        defer { lock.unlock() }
        let pending = items.filter { $0.status == .queued || $0.status == .retrying || $0.status == .processing }.count
        let permanent = items.filter { $0.status == .permanentFailed }.count
        let lastError = items.reversed().compactMap(\.lastErrorCode).first
        return SyncOutboxSummary(pendingCount: pending, permanentFailureCount: permanent, lastErrorCode: lastError)
    }

    @discardableResult
    func flush(using transport: ProfileSyncOutboxTransporting, now: Date = Date()) async -> SyncOutboxSummary {
        let nowTs = now.timeIntervalSince1970
        while let next = nextDispatchableItem(now: nowTs) {
            updateItem(id: next.id) { item in
                item.status = .processing
                item.updatedAt = Date().timeIntervalSince1970
            }

            let result = await transport.send(item: next)
            let currentNow = Date().timeIntervalSince1970
            switch result {
            case .success:
                updateItem(id: next.id) { item in
                    item.status = .completed
                    item.lastErrorCode = nil
                    item.updatedAt = currentNow
                }
            case .retryable(let code):
                let delay = Self.retryDelay(retryCount: next.retryCount + 1)
                updateItem(id: next.id) { item in
                    item.status = .retrying
                    item.retryCount += 1
                    item.lastErrorCode = code
                    item.nextRetryAt = currentNow + delay
                    item.updatedAt = currentNow
                }
                return summary()
            case .permanent(let code):
                updateItem(id: next.id) { item in
                    item.status = .permanentFailed
                    item.lastErrorCode = code
                    item.updatedAt = currentNow
                }
                return summary()
            }
        }
        return summary()
    }

    private static func retryDelay(retryCount: Int) -> TimeInterval {
        let exp = pow(2.0, Double(max(0, retryCount)))
        return min(900.0, 5.0 * exp)
    }

    private func nextDispatchableItem(now: TimeInterval) -> ProfileSyncOutboxItem? {
        lock.lock()
        defer { lock.unlock() }
        return items
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    if lhs.stage.order == rhs.stage.order {
                        return lhs.id < rhs.id
                    }
                    return lhs.stage.order < rhs.stage.order
                }
                return lhs.createdAt < rhs.createdAt
            }
            .first(where: {
                ($0.status == .queued || $0.status == .retrying || $0.status == .processing) &&
                $0.nextRetryAt <= now
            })
    }

    private func updateItem(id: String, _ block: (inout ProfileSyncOutboxItem) -> Void) {
        lock.lock()
        if let idx = items.firstIndex(where: { $0.id == id }) {
            block(&items[idx])
            persistLocked()
        }
        lock.unlock()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ProfileSyncOutboxItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

struct SupabaseProfileSyncTransport: ProfileSyncOutboxTransporting {
    private func endpointURL(from env: [String: String]) -> URL? {
        guard let rawURL = env["SUPABASE_URL"], rawURL.isEmpty == false else { return nil }
        return URL(string: rawURL + "/functions/v1/sync-profile")
    }

    private func bearerToken(from env: [String: String]) -> String {
        env["SUPABASE_ANON_KEY"] ?? ""
    }

    func send(item: ProfileSyncOutboxItem) async -> SyncOutboxSendResult {
        guard AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) else {
            return .retryable(.unauthorized)
        }
        let env = ProcessInfo.processInfo.environment
        guard let url = endpointURL(from: env) else {
            return .retryable(.notConfigured)
        }

        let token = bearerToken(from: env)
        guard token.isEmpty == false else {
            return .retryable(.tokenExpired)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "action": "sync_profile_stage",
            "stage": item.stage.rawValue,
            "user_id": item.userId,
            "idempotency_key": item.idempotencyKey,
            "payload": item.payload
        ]
        body["pet_id"] = item.petId ?? NSNull()
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                return .retryable(.unknown)
            }
            switch statusCode {
            case 200..<300:
                return .success
            case 401, 403:
                return .retryable(.tokenExpired)
            case 429, 500..<600:
                return .retryable(.serverError)
            case 404:
                return .retryable(.notConfigured)
            case 400, 422:
                return .permanent(.schemaMismatch)
            case 507:
                return .permanent(.storageQuota)
            default:
                return .retryable(.unknown)
            }
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .retryable(.offline)
            case .userAuthenticationRequired:
                return .retryable(.tokenExpired)
            default:
                return .retryable(.unknown)
            }
        } catch {
            return .retryable(.unknown)
        }
    }
}

final class ProfileSyncCoordinator {
    static let shared = ProfileSyncCoordinator()

    private let outbox = ProfileSyncOutboxStore.shared
    private let transport = SupabaseProfileSyncTransport()
    private var flushTask: Task<Void, Never>? = nil
    private var lastFlushAt: Date = .distantPast

    private init() {}

    func enqueueSnapshot(userInfo: UserInfo) {
        outbox.enqueueSnapshot(userInfo: userInfo)
    }

    func flushIfNeeded(force: Bool = false) {
        let now = Date()
        if force == false, now.timeIntervalSince(lastFlushAt) < 5.0 {
            return
        }
        guard flushTask == nil else { return }
        lastFlushAt = now
        flushTask = Task { [weak self] in
            guard let self else { return }
            _ = await self.outbox.flush(using: self.transport, now: Date())
            self.flushTask = nil
        }
    }

    func summary() -> SyncOutboxSummary {
        outbox.summary()
    }
}

enum AppSessionState: Equatable {
    case guest
    case member(userId: String)

    var isMember: Bool {
        if case .member = self { return true }
        return false
    }
}

enum FeatureCapability: String, CaseIterable {
    case walkRead = "walk_read"
    case walkWrite = "walk_write"
    case cloudSync = "cloud_sync"
    case aiGeneration = "ai_generation"
    case nearbySocial = "nearby_social"
}

enum FeatureGateDecision: Equatable {
    case allowed
    case requiresMember(MemberUpgradeTrigger)
}

enum AppFeatureGate {
    private enum AccessPolicy {
        case guestAllowed
        case memberOnly(trigger: MemberUpgradeTrigger)
    }

    private static let matrix: [FeatureCapability: AccessPolicy] = [
        .walkRead: .guestAllowed,
        .walkWrite: .guestAllowed,
        .cloudSync: .memberOnly(trigger: .walkHistory),
        .aiGeneration: .memberOnly(trigger: .imageGenerator),
        .nearbySocial: .memberOnly(trigger: .walkHistory),
    ]

    static func currentSession() -> AppSessionState {
        guard let id = UserdefaultSetting.shared.getValue()?.id, id.isEmpty == false else {
            return .guest
        }
        return .member(userId: id)
    }

    static func decision(for capability: FeatureCapability, session: AppSessionState) -> FeatureGateDecision {
        guard let policy = matrix[capability] else {
            return .allowed
        }
        switch policy {
        case .guestAllowed:
            return .allowed
        case .memberOnly(let trigger):
            return session.isMember ? .allowed : .requiresMember(trigger)
        }
    }

    static func isAllowed(_ capability: FeatureCapability, session: AppSessionState = currentSession()) -> Bool {
        if case .allowed = decision(for: capability, session: session) {
            return true
        }
        return false
    }
}

enum MemberUpgradeTrigger: String {
    case walkStart = "walk_start"
    case imageGenerator = "image_generator"
    case walkHistory = "walk_history"
    case walkBackup = "walk_backup"

    var title: String {
        switch self {
        case .walkStart:
            return "회원 전환 후 산책 기록"
        case .imageGenerator:
            return "회원 전환 후 이미지 생성"
        case .walkHistory:
            return "회원 전환 후 기록 동기화"
        case .walkBackup:
            return "로그인하고 산책 백업"
        }
    }

    var message: String {
        switch self {
        case .walkStart:
            return "산책 기록은 계정과 연결되어야 안전하게 저장되고 기기 간 동기화됩니다."
        case .imageGenerator:
            return "AI 이미지 생성 결과를 안정적으로 저장하려면 계정 연동이 필요합니다."
        case .walkHistory:
            return "지금 로그인하면 현재 기기의 산책 기록을 계정에 백업하고 다른 기기에서도 볼 수 있어요."
        case .walkBackup:
            return "게스트 모드 기록은 기기 삭제 시 유실될 수 있어요. 로그인 후 자동 백업을 켜세요."
        }
    }
}

struct MemberUpgradeRequest: Identifiable {
    let id = UUID()
    let trigger: MemberUpgradeTrigger
}

struct GuestDataUpgradeSnapshot: Equatable {
    let sessionCount: Int
    let pointCount: Int
    let totalAreaM2: Double
    let totalDurationSec: Double
    let sessionIds: [String]
    let signature: String
}

struct GuestDataUpgradeReport: Codable, Equatable, Identifiable {
    var id: String { userId + ":" + signature }
    let userId: String
    let signature: String
    let sessionCount: Int
    let pointCount: Int
    let totalAreaM2: Double
    let totalDurationSec: Double
    let pendingCount: Int
    let permanentFailureCount: Int
    let lastErrorCode: String?
    let remoteSessionCount: Int?
    let remotePointCount: Int?
    let remoteTotalAreaM2: Double?
    let remoteTotalDurationSec: Double?
    let validationPassed: Bool?
    let validationMessage: String?
    let executedAt: TimeInterval

    var hasOutstandingWork: Bool {
        pendingCount > 0 || permanentFailureCount > 0
    }
}

struct GuestDataUpgradePrompt: Identifiable {
    let id = UUID()
    let snapshot: GuestDataUpgradeSnapshot
    let shouldEmphasizeRetry: Bool
}

final class GuestDataUpgradeService: CoreDataProtocol {
    static let shared = GuestDataUpgradeService()

    private let syncOutbox = SyncOutboxStore.shared
    private let syncTransport = SupabaseSyncOutboxTransport()
    private let reportStoragePrefix = "guest.data.upgrade.report.v1."
    private let acknowledgedSignaturePrefix = "guest.data.upgrade.signature.v1."

    private init() {}

    func pendingPrompt(for userId: String) -> GuestDataUpgradePrompt? {
        guard let snapshot = localSnapshot(), snapshot.sessionCount > 0 else { return nil }
        let report = latestReport(for: userId)
        let acknowledgedSignature = UserDefaults.standard.string(forKey: signatureKey(for: userId))
        if acknowledgedSignature == snapshot.signature, report?.hasOutstandingWork == false {
            return nil
        }
        return GuestDataUpgradePrompt(
            snapshot: snapshot,
            shouldEmphasizeRetry: report?.hasOutstandingWork == true
        )
    }

    func latestReport(for userId: String) -> GuestDataUpgradeReport? {
        guard let data = UserDefaults.standard.data(forKey: reportKey(for: userId)),
              let decoded = try? JSONDecoder().decode(GuestDataUpgradeReport.self, from: data) else {
            return nil
        }
        return decoded
    }

    func runUpgrade(for userId: String, forceRetry: Bool = false) async -> GuestDataUpgradeReport? {
        guard let snapshot = localSnapshot(), snapshot.sessionCount > 0 else { return nil }

        if forceRetry {
            syncOutbox.requeuePermanentFailures(walkSessionIds: Set(snapshot.sessionIds))
        }

        for polygon in fetchPolygons() {
            guard let sessionDTO = CoreDataSupabaseBackfillDTOConverter.makeSessionDTO(
                from: polygon,
                ownerUserId: userId,
                petId: nil,
                sourceDevice: "ios"
            ) else { continue }
            syncOutbox.enqueueWalkStages(sessionDTO: sessionDTO)
        }

        let summary = await syncOutbox.flush(using: syncTransport, now: Date())
        let remoteSummary = await syncTransport.fetchBackfillValidationSummary(sessionIds: snapshot.sessionIds)
        let validation = validate(local: snapshot, remote: remoteSummary)
        let report = GuestDataUpgradeReport(
            userId: userId,
            signature: snapshot.signature,
            sessionCount: snapshot.sessionCount,
            pointCount: snapshot.pointCount,
            totalAreaM2: snapshot.totalAreaM2,
            totalDurationSec: snapshot.totalDurationSec,
            pendingCount: summary.pendingCount,
            permanentFailureCount: summary.permanentFailureCount,
            lastErrorCode: summary.lastErrorCode?.rawValue,
            remoteSessionCount: remoteSummary?.sessionCount,
            remotePointCount: remoteSummary?.pointCount,
            remoteTotalAreaM2: remoteSummary?.totalAreaM2,
            remoteTotalDurationSec: remoteSummary?.totalDurationSec,
            validationPassed: validation.passed,
            validationMessage: validation.message,
            executedAt: Date().timeIntervalSince1970
        )

        persist(report: report, for: userId)
        if report.hasOutstandingWork == false {
            UserDefaults.standard.set(snapshot.signature, forKey: signatureKey(for: userId))
        }
        return report
    }

    private func localSnapshot() -> GuestDataUpgradeSnapshot? {
        let polygons = fetchPolygons()
        guard polygons.isEmpty == false else { return nil }

        let sessionIds = polygons.map { $0.id.uuidString.lowercased() }.sorted()
        let pointCount = polygons.reduce(0) { $0 + $1.locations.count }
        let totalArea = polygons.reduce(0.0) { $0 + $1.walkingArea }
        let totalDuration = polygons.reduce(0.0) { $0 + $1.walkingTime }
        let signature = signatureForSnapshot(
            sessionIds: sessionIds,
            pointCount: pointCount,
            totalAreaM2: totalArea,
            totalDurationSec: totalDuration
        )
        return GuestDataUpgradeSnapshot(
            sessionCount: sessionIds.count,
            pointCount: pointCount,
            totalAreaM2: totalArea,
            totalDurationSec: totalDuration,
            sessionIds: sessionIds,
            signature: signature
        )
    }

    private func persist(report: GuestDataUpgradeReport, for userId: String) {
        guard let data = try? JSONEncoder().encode(report) else { return }
        UserDefaults.standard.set(data, forKey: reportKey(for: userId))
    }

    private func validate(
        local: GuestDataUpgradeSnapshot,
        remote: SyncBackfillValidationSummary?
    ) -> (passed: Bool?, message: String?) {
        guard let remote else {
            return (nil, "remote_summary_unavailable")
        }
        let areaTolerance = max(1.0, local.totalAreaM2 * 0.01)
        let durationTolerance = max(3.0, local.totalDurationSec * 0.01)

        let sessionMatched = local.sessionCount == remote.sessionCount
        let pointMatched = local.pointCount == remote.pointCount
        let areaMatched = abs(local.totalAreaM2 - remote.totalAreaM2) <= areaTolerance
        let durationMatched = abs(local.totalDurationSec - remote.totalDurationSec) <= durationTolerance
        let passed = sessionMatched && pointMatched && areaMatched && durationMatched

        let message = passed
        ? "validated"
        : [
            sessionMatched ? nil : "session_mismatch",
            pointMatched ? nil : "point_mismatch",
            areaMatched ? nil : "area_mismatch",
            durationMatched ? nil : "duration_mismatch"
        ].compactMap { $0 }.joined(separator: ",")

        return (passed, message)
    }

    private func reportKey(for userId: String) -> String {
        reportStoragePrefix + stableKey(from: userId)
    }

    private func signatureKey(for userId: String) -> String {
        acknowledgedSignaturePrefix + stableKey(from: userId)
    }

    private func signatureForSnapshot(
        sessionIds: [String],
        pointCount: Int,
        totalAreaM2: Double,
        totalDurationSec: Double
    ) -> String {
        let payload = sessionIds.joined(separator: "|")
        + "|p:\(pointCount)"
        + "|a:\(totalAreaM2)"
        + "|t:\(totalDurationSec)"
        return stableKey(from: payload)
    }

    private func stableKey(from raw: String) -> String {
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class AuthFlowCoordinator: ObservableObject {
    @Published var shouldShowEntryChoice: Bool = false
    @Published var shouldShowSignIn: Bool = false
    @Published var pendingUpgradeRequest: MemberUpgradeRequest? = nil
    @Published var pendingGuestDataUpgradePrompt: GuestDataUpgradePrompt? = nil
    @Published var guestDataUpgradeInProgress: Bool = false
    @Published var guestDataUpgradeResult: GuestDataUpgradeReport? = nil

    private let guestModeKey = "auth.guest_mode.v1"
    private let entryChoiceCompletedKey = "auth.entry_choice_completed.v1"
    private let guestDataUpgradeService = GuestDataUpgradeService.shared
    private var onAuthenticated: (() -> Void)?

    var sessionState: AppSessionState {
        AppFeatureGate.currentSession()
    }

    var isLoggedIn: Bool {
        sessionState.isMember
    }

    var isGuestMode: Bool {
        isLoggedIn == false && UserDefaults.standard.bool(forKey: guestModeKey)
    }

    func refresh() {
        if isLoggedIn {
            UserDefaults.standard.set(false, forKey: guestModeKey)
            UserDefaults.standard.set(true, forKey: entryChoiceCompletedKey)
            shouldShowEntryChoice = false
            shouldShowSignIn = false
            pendingUpgradeRequest = nil
            return
        }
        pendingGuestDataUpgradePrompt = nil
        guestDataUpgradeInProgress = false
        guestDataUpgradeResult = nil
        let didChooseEntryPath = UserDefaults.standard.bool(forKey: entryChoiceCompletedKey)
        shouldShowEntryChoice = !didChooseEntryPath
    }

    func continueAsGuest() {
        UserDefaults.standard.set(true, forKey: guestModeKey)
        UserDefaults.standard.set(true, forKey: entryChoiceCompletedKey)
        shouldShowEntryChoice = false
    }

    func chooseSignInFromEntry() {
        UserDefaults.standard.set(true, forKey: entryChoiceCompletedKey)
        shouldShowEntryChoice = false
        shouldShowSignIn = true
    }

    func canAccess(_ feature: FeatureCapability) -> Bool {
        AppFeatureGate.isAllowed(feature, session: sessionState)
    }

    @discardableResult
    func requestAccess(feature: FeatureCapability, onAllowed: (() -> Void)? = nil) -> Bool {
        let decision = AppFeatureGate.decision(for: feature, session: sessionState)
        switch decision {
        case .allowed:
            onAllowed?()
            return true
        case .requiresMember(let trigger):
            return requireMember(trigger: trigger, onAuthenticated: onAllowed)
        }
    }

    @discardableResult
    func requireMember(trigger: MemberUpgradeTrigger, onAuthenticated: (() -> Void)? = nil) -> Bool {
        if isLoggedIn {
            onAuthenticated?()
            return true
        }
        self.onAuthenticated = onAuthenticated
        pendingUpgradeRequest = MemberUpgradeRequest(trigger: trigger)
        return false
    }

    func proceedToSignIn() {
        pendingUpgradeRequest = nil
        shouldShowSignIn = true
    }

    func dismissUpgradeRequest() {
        pendingUpgradeRequest = nil
        onAuthenticated = nil
    }

    func dismissSignIn() {
        shouldShowSignIn = false
        if isLoggedIn == false {
            UserDefaults.standard.set(true, forKey: guestModeKey)
        }
        onAuthenticated = nil
    }

    func startReauthenticationFlow() {
        pendingUpgradeRequest = nil
        pendingGuestDataUpgradePrompt = nil
        shouldShowEntryChoice = false
        shouldShowSignIn = true
    }

    func dismissGuestDataUpgradePrompt() {
        pendingGuestDataUpgradePrompt = nil
    }

    func clearGuestDataUpgradeResult() {
        guestDataUpgradeResult = nil
    }

    func startGuestDataUpgrade(forceRetry: Bool = false) {
        guard let userId = UserdefaultSetting.shared.getValue()?.id, userId.isEmpty == false else {
            return
        }
        pendingGuestDataUpgradePrompt = nil
        guestDataUpgradeInProgress = true
        Task {
            let report = await guestDataUpgradeService.runUpgrade(for: userId, forceRetry: forceRetry)
            await MainActor.run {
                self.guestDataUpgradeInProgress = false
                self.guestDataUpgradeResult = report
            }
        }
    }

    func latestGuestDataUpgradeReport() -> GuestDataUpgradeReport? {
        guard let userId = UserdefaultSetting.shared.getValue()?.id, userId.isEmpty == false else {
            return nil
        }
        return guestDataUpgradeService.latestReport(for: userId)
    }

    func completeSignIn() {
        UserDefaults.standard.set(false, forKey: guestModeKey)
        UserDefaults.standard.set(true, forKey: entryChoiceCompletedKey)
        shouldShowSignIn = false
        shouldShowEntryChoice = false
        pendingUpgradeRequest = nil
        if let userId = UserdefaultSetting.shared.getValue()?.id, userId.isEmpty == false {
            pendingGuestDataUpgradePrompt = guestDataUpgradeService.pendingPrompt(for: userId)
            guestDataUpgradeResult = guestDataUpgradeService.latestReport(for: userId)
        }
        let completion = onAuthenticated
        onAuthenticated = nil
        completion?()
    }
}

struct MemberUpgradeSheetView: View {
    let request: MemberUpgradeRequest
    let onUpgrade: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(request.trigger.title)
                .font(.appFont(for: .Bold, size: 22))
                .foregroundStyle(Color.appTextDarkGray)
            Text(request.trigger.message)
                .font(.appFont(for: .Regular, size: 14))
                .foregroundStyle(Color.appTextDarkGray)
            VStack(alignment: .leading, spacing: 8) {
                Text("• 계정 연동 후 자동 백업")
                Text("• 기기 변경 시 기록 복원")
                Text("• 로그인 완료 후 현재 화면으로 복귀")
            }
            .font(.appFont(for: .Regular, size: 13))
            .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 10) {
                Button("나중에") {
                    onLater()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appYellowPale)
                .foregroundStyle(Color.appTextDarkGray)
                .cornerRadius(10)

                Button("로그인하고 계속") {
                    onUpgrade()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appGreen)
                .foregroundStyle(Color.white)
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color.white)
    }
}

struct GuestDataUpgradePromptSheetView: View {
    let prompt: GuestDataUpgradePrompt
    let onImport: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(prompt.shouldEmphasizeRetry ? "산책 데이터 이관 재시도" : "게스트 산책 데이터 가져오기")
                .font(.appFont(for: .Bold, size: 22))
                .foregroundStyle(Color.appTextDarkGray)
            Text("로그인 전에 기록한 산책 데이터를 계정으로 이관합니다. 중복 없이 안전하게 처리돼요.")
                .font(.appFont(for: .Regular, size: 14))
                .foregroundStyle(Color.appTextDarkGray)
            VStack(alignment: .leading, spacing: 6) {
                Text("세션 \(prompt.snapshot.sessionCount)건")
                Text("포인트 \(prompt.snapshot.pointCount)건")
                Text("누적 면적 \(prompt.snapshot.totalAreaM2.calculatedAreaString)")
                Text("누적 시간 \(prompt.snapshot.totalDurationSec.walkingTimeInterval)")
            }
            .font(.appFont(for: .Regular, size: 13))
            .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 10) {
                Button("나중에") {
                    onLater()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appYellowPale)
                .foregroundStyle(Color.appTextDarkGray)
                .cornerRadius(10)

                Button(prompt.shouldEmphasizeRetry ? "다시 가져오기" : "가져오기") {
                    onImport()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appGreen)
                .foregroundStyle(Color.white)
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color.white)
    }
}
