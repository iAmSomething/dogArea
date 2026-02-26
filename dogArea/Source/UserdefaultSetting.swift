//
//  UserdefaultSetting.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import Foundation
import CryptoKit
class UserdefaultSetting {
    enum keyValue: String {
        case userId = "userId"
        case userName = "userName"
        case userProfile = "userProfile"
        case petInfo = "petInfo"
        case selectedPetId = "selectedPetId"
        case walkStartCountdownEnabled = "walkStartCountdownEnabled"
        case walkPointRecordMode = "walkPointRecordMode"
        case walkAutoEndPolicyEnabled = "walkAutoEndPolicyEnabled"
        case createdAt = "createdAt"
        case nonce = "nonce"
    }
    static var shared = UserdefaultSetting()
    func savenonce(nonce: Double) {
        UserDefaults.standard.setValue(nonce, forKey: keyValue.nonce.rawValue)
    }
    func save(
        id: String,
        name: String,
        profile: String?,
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
        UserDefaults.standard.setStructArray(normalizedPets, forKey: keyValue.petInfo.rawValue)
        UserDefaults.standard.setValue(resolvedSelectedPetId, forKey: keyValue.selectedPetId.rawValue)
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
                pet: pets,
                createdAt: createdAt,
                selectedPetId: selectedPetId
            )
        }
        if let profile = UserDefaults.standard.string(forKey: keyValue.userProfile.rawValue){
            return .init(id: id, name: name, profile: profile, pet: pets, createdAt: createdAt)
        } else {
            return .init(id: id, name: name, profile: nil, pet: pets, createdAt: createdAt)
        }
    }
    #if DEBUG
    func removeAll() {
        UserDefaults.standard.removeObject(forKey: keyValue.userId.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.userName.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.userProfile.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.petInfo.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.selectedPetId.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.walkStartCountdownEnabled.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.walkPointRecordMode.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.walkAutoEndPolicyEnabled.rawValue)
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
    let pet: [PetInfo]
    var createdAt: TimeInterval
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
    var caricatureURL: String? = nil
    var caricatureStatus: CaricatureStatus? = nil
    var caricatureProvider: String? = nil

    init(
        petId: String = UUID().uuidString.lowercased(),
        petName: String,
        petProfile: String?,
        caricatureURL: String? = nil,
        caricatureStatus: CaricatureStatus? = nil,
        caricatureProvider: String? = nil
    ) {
        self.petId = petId
        self.petName = petName
        self.petProfile = petProfile
        self.caricatureURL = caricatureURL
        self.caricatureStatus = caricatureStatus
        self.caricatureProvider = caricatureProvider
    }

    enum CodingKeys: String, CodingKey {
        case petId
        case petName
        case petProfile
        case caricatureURL
        case caricatureStatus
        case caricatureProvider
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.petId = try container.decodeIfPresent(String.self, forKey: .petId) ?? UUID().uuidString.lowercased()
        self.petName = try container.decode(String.self, forKey: .petName)
        self.petProfile = try container.decodeIfPresent(String.self, forKey: .petProfile)
        self.caricatureURL = try container.decodeIfPresent(String.self, forKey: .caricatureURL)
        self.caricatureStatus = try container.decodeIfPresent(CaricatureStatus.self, forKey: .caricatureStatus)
        self.caricatureProvider = try container.decodeIfPresent(String.self, forKey: .caricatureProvider)
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
    func selectedPetId() -> String? {
        UserDefaults.standard.string(forKey: keyValue.selectedPetId.rawValue)
    }

    func setSelectedPetId(_ petId: String) {
        guard let current = getValue(), current.pet.contains(where: { $0.petId == petId }) else {
            return
        }
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
    }

    func selectedPet(from userInfo: UserInfo? = nil) -> PetInfo? {
        let info = userInfo ?? getValue()
        guard let info else { return nil }
        let selectedId = selectedPetId()
        return info.pet.first(where: { $0.petId == selectedId }) ?? info.pet.first
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

    func walkAutoEndPolicyEnabled() -> Bool {
        UserDefaults.standard.object(forKey: keyValue.walkAutoEndPolicyEnabled.rawValue) as? Bool ?? true
    }

    func setWalkAutoEndPolicyEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: keyValue.walkAutoEndPolicyEnabled.rawValue)
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
