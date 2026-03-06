//
//  UserdefaultSetting.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import Foundation
import CryptoKit
import SwiftUI
import Combine

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
        case seasonCatchupBuffSnapshot = "seasonCatchupBuffSnapshot"
        case createdAt = "createdAt"
        case nonce = "nonce"
    }

    static var shared = UserdefaultSetting()
    static let selectedPetDidChangeNotification = PetSelectionStore.selectedPetDidChangeNotification
    static let seasonCatchupBuffDidUpdateNotification = Notification.Name("userdefault.seasonCatchupBuffDidUpdate")

    private let userDefaults: UserDefaults
    private let profileStore: ProfileStoring
    private let petSelectionStore: PetSelectionStoring
    private let walkSessionMetadataStore: WalkSessionMetadataStore

    init(
        userDefaults: UserDefaults = .standard,
        profileStore: ProfileStoring = ProfileStore.shared,
        petSelectionStore: PetSelectionStoring = PetSelectionStore.shared,
        walkSessionMetadataStore: WalkSessionMetadataStore = .shared
    ) {
        self.userDefaults = userDefaults
        self.profileStore = profileStore
        self.petSelectionStore = petSelectionStore
        self.walkSessionMetadataStore = walkSessionMetadataStore
    }

    func savenonce(nonce: Double) {
        userDefaults.setValue(nonce, forKey: keyValue.nonce.rawValue)
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
        profileStore.save(
            id: id,
            name: name,
            profile: profile,
            profileMessage: profileMessage,
            pet: pet,
            createdAt: createdAt,
            selectedPetId: selectedPetId
        )
    }

    func getValue() -> UserInfo? {
        profileStore.getValue()
    }

    #if DEBUG
    func removeAll() {
        profileStore.removeAll()
        petSelectionStore.clearSelectionState()
        walkSessionMetadataStore.clearPreferences()
        userDefaults.removeObject(forKey: keyValue.selectedPetId.rawValue)
        userDefaults.removeObject(forKey: keyValue.walkStartCountdownEnabled.rawValue)
        userDefaults.removeObject(forKey: keyValue.walkPointRecordMode.rawValue)
    }
    #endif
}

extension Notification.Name {
    static let walkPointRecordedForQuest = Notification.Name("walk.point.recorded.for.quest")
    static let authSessionDidChange = Notification.Name("auth.session.didChange")
}
struct UserInfo: TimeCheckable {
    let id: String
    let name: String
    let profile: String?
    let profileMessage: String?
    let pet: [PetInfo]
    var selectedPetId: String?
    var createdAt: TimeInterval
    var selectedPet: PetInfo? {
        guard !pet.isEmpty else { return nil }
        guard let selectedPetId = selectedPetId else { return pet.first }
        return pet.first(where: { $0.id == selectedPetId }) ?? pet.first
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
        let data = value.compactMap { try? JSONEncoder().encode($0) }
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
        petSelectionStore.selectedPetId()
    }

    func setSelectedPetId(_ petId: String, source: String = "manual") {
        petSelectionStore.setSelectedPetId(petId, source: source)
    }

    func selectedPet(from userInfo: UserInfo? = nil) -> PetInfo? {
        let info = userInfo ?? getValue()
        return petSelectionStore.selectedPet(from: info)
    }

    func suggestedPetForWalkStart(from userInfo: UserInfo? = nil, now: Date = Date()) -> PetInfo? {
        let info = userInfo ?? getValue()
        return petSelectionStore.suggestedPetForWalkStart(from: info, now: now)
    }

    func recentPetSelectionEvents() -> [PetSelectionEvent] {
        petSelectionStore.recentPetSelectionEvents()
    }

    func updateFirstPetCaricature(
        status: CaricatureStatus,
        caricatureURL: String? = nil,
        provider: String? = nil
    ) {
        guard let current = getValue(), current.pet.isEmpty == false else { return }
        let targetPetId = selectedPet(from: current)?.petId ?? current.pet.first?.petId
        guard let targetPetId else { return }
        _ = profileStore.updatePetCaricature(
            status: status,
            targetPetId: targetPetId,
            caricatureURL: caricatureURL,
            provider: provider
        )
    }

    func seasonCatchupBuffSnapshot() -> SeasonCatchupBuffSnapshot? {
        userDefaults.structData(
            SeasonCatchupBuffSnapshot.self,
            forKey: keyValue.seasonCatchupBuffSnapshot.rawValue
        )
    }

    func updateSeasonCatchupBuffSnapshot(_ snapshot: SeasonCatchupBuffSnapshot) {
        userDefaults.setStruct(snapshot, forKey: keyValue.seasonCatchupBuffSnapshot.rawValue)
        NotificationCenter.default.post(
            name: UserdefaultSetting.seasonCatchupBuffDidUpdateNotification,
            object: nil,
            userInfo: [
                "status": snapshot.status.rawValue,
                "isActive": snapshot.isActive,
                "walkSessionId": snapshot.walkSessionId
            ]
        )
    }

    func walkStartCountdownEnabled() -> Bool {
        walkSessionMetadataStore.walkStartCountdownEnabled()
    }

    func setWalkStartCountdownEnabled(_ enabled: Bool) {
        walkSessionMetadataStore.setWalkStartCountdownEnabled(enabled)
    }

    func walkPointRecordModeRawValue() -> String {
        walkSessionMetadataStore.walkPointRecordModeRawValue()
    }

    func setWalkPointRecordModeRawValue(_ rawValue: String) {
        walkSessionMetadataStore.setWalkPointRecordModeRawValue(rawValue)
    }

}

protocol UserSessionStoreProtocol {
    func currentUserInfo() -> UserInfo?
    func selectedPet(from userInfo: UserInfo?) -> PetInfo?
    func setSelectedPetId(_ petId: String, source: String)
    func suggestedPetForWalkStart(from userInfo: UserInfo?, now: Date) -> PetInfo?
    func seasonCatchupBuffSnapshot() -> SeasonCatchupBuffSnapshot?
    func walkStartCountdownEnabled() -> Bool
    func setWalkStartCountdownEnabled(_ enabled: Bool)
    func walkPointRecordModeRawValue() -> String
    func setWalkPointRecordModeRawValue(_ rawValue: String)
}

final class DefaultUserSessionStore: UserSessionStoreProtocol {
    static let shared = DefaultUserSessionStore()
    private let storage: UserdefaultSetting

    init(storage: UserdefaultSetting = .shared) {
        self.storage = storage
    }

    func currentUserInfo() -> UserInfo? {
        storage.getValue()
    }

    func selectedPet(from userInfo: UserInfo?) -> PetInfo? {
        storage.selectedPet(from: userInfo)
    }

    func setSelectedPetId(_ petId: String, source: String) {
        storage.setSelectedPetId(petId, source: source)
    }

    func suggestedPetForWalkStart(from userInfo: UserInfo?, now: Date) -> PetInfo? {
        storage.suggestedPetForWalkStart(from: userInfo, now: now)
    }

    func seasonCatchupBuffSnapshot() -> SeasonCatchupBuffSnapshot? {
        storage.seasonCatchupBuffSnapshot()
    }

    func walkStartCountdownEnabled() -> Bool {
        storage.walkStartCountdownEnabled()
    }

    func setWalkStartCountdownEnabled(_ enabled: Bool) {
        storage.setWalkStartCountdownEnabled(enabled)
    }

    func walkPointRecordModeRawValue() -> String {
        storage.walkPointRecordModeRawValue()
    }

    func setWalkPointRecordModeRawValue(_ rawValue: String) {
        storage.setWalkPointRecordModeRawValue(rawValue)
    }
}

protocol MapPreferenceStoreProtocol {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool
    func integer(forKey key: String, default defaultValue: Int) -> Int
    func double(forKey key: String, default defaultValue: Double) -> Double
    func string(forKey key: String) -> String?
    func data(forKey key: String) -> Data?
    func stringArray(forKey key: String) -> [String]
    func set(_ value: Bool, forKey key: String)
    func set(_ value: String?, forKey key: String)
    func set(_ value: Data?, forKey key: String)
    func set(_ value: [String], forKey key: String)
    func removeObject(forKey key: String)
}

final class DefaultMapPreferenceStore: MapPreferenceStoreProtocol {
    static let shared = DefaultMapPreferenceStore()
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        guard let value = userDefaults.object(forKey: key) as? Bool else {
            return defaultValue
        }
        return value
    }

    func integer(forKey key: String, default defaultValue: Int) -> Int {
        let value = userDefaults.integer(forKey: key)
        return value > 0 ? value : defaultValue
    }

    func double(forKey key: String, default defaultValue: Double) -> Double {
        let value = userDefaults.double(forKey: key)
        return value > 0 ? value : defaultValue
    }

    func string(forKey key: String) -> String? {
        userDefaults.string(forKey: key)
    }

    func data(forKey key: String) -> Data? {
        userDefaults.data(forKey: key)
    }

    func stringArray(forKey key: String) -> [String] {
        userDefaults.stringArray(forKey: key) ?? []
    }

    func set(_ value: Bool, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    func set(_ value: String?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    func set(_ value: Data?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    func set(_ value: [String], forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    func removeObject(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
}

protocol AppEventCenterProtocol {
    func addObserver(
        forName name: Notification.Name,
        object: AnyObject?,
        queue: OperationQueue?,
        using block: @escaping (Notification) -> Void
    ) -> NSObjectProtocol
    func removeObserver(_ observer: NSObjectProtocol)
    func post(name: Notification.Name, object: AnyObject?, userInfo: [AnyHashable: Any]?)
    func publisher(for name: Notification.Name, object: AnyObject?) -> AnyPublisher<Notification, Never>
}

final class DefaultAppEventCenter: AppEventCenterProtocol {
    static let shared = DefaultAppEventCenter()
    private let center: NotificationCenter

    init(center: NotificationCenter = .default) {
        self.center = center
    }

    func addObserver(
        forName name: Notification.Name,
        object: AnyObject?,
        queue: OperationQueue?,
        using block: @escaping (Notification) -> Void
    ) -> NSObjectProtocol {
        center.addObserver(forName: name, object: object, queue: queue, using: block)
    }

    func removeObserver(_ observer: NSObjectProtocol) {
        center.removeObserver(observer)
    }

    func post(name: Notification.Name, object: AnyObject?, userInfo: [AnyHashable: Any]?) {
        center.post(name: name, object: object, userInfo: userInfo)
    }

    func publisher(for name: Notification.Name, object: AnyObject? = nil) -> AnyPublisher<Notification, Never> {
        center.publisher(for: name, object: object).eraseToAnyPublisher()
    }
}

enum AppFeatureFlagKey: String, CaseIterable {
    case heatmapV1 = "ff_heatmap_v1"
    case caricatureAsyncV1 = "ff_caricature_async_v1"
    case nearbyHotspotV1 = "ff_nearby_hotspot_v1"
    case repoLayerV2 = "ff_repo_layer_v2"
    case supabaseReadV1 = "ff_supabase_read_v1"
    case coredataDeprecationV1 = "ff_coredata_deprecation_v1"
}

enum AppMetricEvent: String {
    case walkSaveSuccess = "walk_save_success"
    case walkSaveFailed = "walk_save_failed"
    case watchActionReceived = "watch_action_received"
    case watchActionProcessed = "watch_action_processed"
    case watchActionApplied = "watch_action_applied"
    case watchActionDuplicate = "watch_action_duplicate"
    case widgetActionApplied = "widget_action_applied"
    case widgetActionRejected = "widget_action_rejected"
    case widgetActionDuplicate = "widget_action_duplicate"
    case caricatureSuccess = "caricature_success"
    case caricatureFailed = "caricature_failed"
    case nearbyOptInEnabled = "nearby_opt_in_enabled"
    case nearbyOptInDisabled = "nearby_opt_in_disabled"
    case petSelectionChanged = "pet_selection_changed"
    case petSelectionSuggested = "pet_selection_suggested"
    case recoveryDraftDetected = "recovery_draft_detected"
    case recoveryDraftDiscarded = "recovery_draft_discarded"
    case recoveryFinalizeConfirmed = "recovery_finalize_confirmed"
    case recoveryFinalizeFailed = "recovery_finalize_failed"
    case indoorMissionReplacementApplied = "indoor_mission_replacement_applied"
    case indoorMissionActionLogged = "indoor_mission_action_logged"
    case indoorMissionCompleted = "indoor_mission_completed"
    case indoorMissionCompletionRejected = "indoor_mission_completion_rejected"
    case indoorMissionExtensionApplied = "indoor_mission_extension_applied"
    case indoorMissionExtensionConsumed = "indoor_mission_extension_consumed"
    case indoorMissionExtensionExpired = "indoor_mission_extension_expired"
    case indoorMissionExtensionBlocked = "indoor_mission_extension_blocked"
    case indoorMissionDifficultyAdjusted = "indoor_mission_difficulty_adjusted"
    case indoorMissionEasyDayActivated = "indoor_mission_easy_day_activated"
    case indoorMissionEasyDayRejected = "indoor_mission_easy_day_rejected"
    case weatherFeedbackSubmitted = "weather_feedback_submitted"
    case weatherFeedbackRateLimited = "weather_feedback_rate_limited"
    case weatherRiskReevaluated = "weather_risk_reevaluated"
    case syncAuthRefreshSucceeded = "sync_auth_refresh_succeeded"
    case syncAuthRefreshFailed = "sync_auth_refresh_failed"
    case rivalPrivacyOptInCompleted = "rival_privacy_opt_in_completed"
    case rivalLeaderboardFetched = "rival_leaderboard_fetched"
    case rivalHotspotFetchSucceeded = "rival_hotspot_fetch_succeeded"
    case rivalHotspotFetchFailed = "rival_hotspot_fetch_failed"
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

    private enum RefreshGateDecision {
        case proceed
        case throttled
        case inFlight
    }

    private let stateQueue = DispatchQueue(label: "com.th.dogArea.feature-flag-store.state")
    private let cacheStorageKey = "feature.flags.cache.v1"
    private let appInstanceStorageKey = "feature.flags.appInstance.v1"
    private let lastRefreshAtStorageKey = "feature.flags.last_refresh_at.v1"
    private let minimumRefreshInterval: TimeInterval = 60
    private var cached: [String: FeatureFlagValue] = [:]
    private var lastRefreshAt: TimeInterval = 0
    private var isRefreshInFlight: Bool = false
    private let appInstance: String

    private let defaults: [String: FeatureFlagValue] = [
        AppFeatureFlagKey.heatmapV1.rawValue: .init(isEnabled: true, rolloutPercent: 100, updatedAt: nil),
        AppFeatureFlagKey.caricatureAsyncV1.rawValue: .init(isEnabled: true, rolloutPercent: 100, updatedAt: nil),
        AppFeatureFlagKey.nearbyHotspotV1.rawValue: .init(isEnabled: true, rolloutPercent: 100, updatedAt: nil),
        AppFeatureFlagKey.repoLayerV2.rawValue: .init(isEnabled: true, rolloutPercent: 100, updatedAt: nil),
        AppFeatureFlagKey.supabaseReadV1.rawValue: .init(isEnabled: true, rolloutPercent: 100, updatedAt: nil),
        AppFeatureFlagKey.coredataDeprecationV1.rawValue: .init(isEnabled: true, rolloutPercent: 100, updatedAt: nil),
    ]

    private init() {
        appInstance = Self.loadOrCreateAppInstance(storageKey: appInstanceStorageKey)
        loadCachedFlags()
        loadLastRefreshAt()
    }

    var appInstanceId: String { appInstance }

    func isEnabled(_ key: AppFeatureFlagKey) -> Bool {
        stateQueue.sync {
            let flag = cached[key.rawValue] ?? defaults[key.rawValue] ?? .init(isEnabled: true, rolloutPercent: 100, updatedAt: nil)
            return isEnabled(flag: flag, key: key.rawValue)
        }
    }

    /// 원격 feature flag를 갱신하되, 내부 스로틀 정책을 적용해 과도한 재호출을 방지합니다.
    /// - Returns: 원격 갱신 성공 또는 스로틀로 인해 캐시 유지가 유효하면 `true`, 실패 시 `false`입니다.
    @discardableResult
    func refresh() async -> Bool {
        await refresh(force: false)
    }

    /// 원격 feature flag를 갱신하고 성공 시 로컬 캐시를 업데이트합니다.
    /// - Parameter force: `true`면 최소 갱신 간격 스로틀을 무시하고 즉시 원격 호출합니다.
    /// - Returns: 원격 갱신 성공 또는 스로틀로 인해 캐시 유지가 유효하면 `true`, 실패 시 `false`입니다.
    @discardableResult
    func refresh(force: Bool) async -> Bool {
        let now = Date()
        switch evaluateRefreshGate(force: force, now: now) {
        case .throttled:
            #if DEBUG
            print("[FeatureFlag] refresh skipped: throttled")
            #endif
            return true
        case .inFlight:
            #if DEBUG
            print("[FeatureFlag] refresh skipped: in-flight")
            #endif
            return true
        case .proceed:
            break
        }
        defer { finishRefreshCycle() }
        do {
            let nowEpoch = now.timeIntervalSince1970
            let data = try await FeatureControlService.shared.post(payload: [
                "action": "get_flags",
                "keys": AppFeatureFlagKey.allCases.map(\.rawValue)
            ])
            let decoded = try JSONDecoder().decode(FeatureFlagEnvelope.self, from: data)
            let newValues = Dictionary(uniqueKeysWithValues: decoded.flags.map {
                ($0.key, FeatureFlagValue(isEnabled: $0.isEnabled, rolloutPercent: $0.rolloutPercent, updatedAt: $0.updatedAt))
            })
            stateQueue.sync {
                cached.merge(newValues) { _, latest in latest }
                lastRefreshAt = nowEpoch
                persistCachedFlags()
                persistLastRefreshAtLocked()
            }
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

    private static func loadOrCreateAppInstance(storageKey: String) -> String {
        if let existing = UserDefaults.standard.string(forKey: storageKey), existing.isEmpty == false {
            return existing
        }
        let generated = UUID().uuidString.lowercased()
        UserDefaults.standard.set(generated, forKey: storageKey)
        return generated
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

    /// 마지막 원격 갱신 시각을 로드해 스로틀 계산의 기준으로 사용합니다.
    private func loadLastRefreshAt() {
        let saved = UserDefaults.standard.double(forKey: lastRefreshAtStorageKey)
        stateQueue.sync {
            lastRefreshAt = saved
        }
    }

    /// 마지막 원격 갱신 시각을 UserDefaults에 저장합니다.
    private func persistLastRefreshAtLocked() {
        UserDefaults.standard.set(lastRefreshAt, forKey: lastRefreshAtStorageKey)
    }

    /// 최소 갱신 간격 정책에 따라 이번 원격 갱신을 생략할지 판정합니다.
    /// - Parameters:
    ///   - force: `true`면 강제 갱신으로 스로틀을 무시합니다.
    ///   - now: 스로틀 계산 기준 시각입니다.
    /// - Returns: 스로틀에 의해 원격 갱신을 생략해야 하면 `true`, 아니면 `false`입니다.
    private func shouldSkipRefresh(force: Bool, now: Date) -> Bool {
        guard force == false else { return false }
        let nowEpoch = now.timeIntervalSince1970
        return stateQueue.sync {
            let elapsed = nowEpoch - lastRefreshAt
            return elapsed >= 0 && elapsed < minimumRefreshInterval
        }
    }

    /// 스로틀/동시 실행 상태를 평가해 원격 갱신을 진행할지 여부를 결정합니다.
    /// - Parameters:
    ///   - force: `true`면 스로틀 평가를 무시하고 강제 갱신을 허용합니다.
    ///   - now: 평가 시점 기준 시각입니다.
    /// - Returns: 이번 호출의 갱신 게이트 결정 결과입니다.
    private func evaluateRefreshGate(force: Bool, now: Date) -> RefreshGateDecision {
        if shouldSkipRefresh(force: force, now: now) {
            return .throttled
        }
        return stateQueue.sync {
            if isRefreshInFlight {
                return .inFlight
            }
            isRefreshInFlight = true
            return .proceed
        }
    }

    /// 원격 feature flag 갱신 시도 종료 시 in-flight 상태를 해제합니다.
    private func finishRefreshCycle() {
        stateQueue.sync {
            isRefreshInFlight = false
        }
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

    private let stateQueue = DispatchQueue(label: "com.th.dogArea.sync-outbox-store.state")
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
                        "points_json": sessionDTO.pointsJSONString,
                        "route_point_count": String(sessionDTO.routePoints.count),
                        "mark_point_count": String(sessionDTO.markPoints.count),
                        "route_points_json": sessionDTO.routePointsJSONString,
                        "mark_points_json": sessionDTO.markPointsJSONString
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

        stateQueue.sync {
            var mutableItems = items
            var enqueuedCount = 0
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
                enqueuedCount += 1
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
            #if DEBUG
            if enqueuedCount > 0 {
                print("[SyncOutbox] enqueue session=\(sessionId) stages=\(enqueuedCount) total=\(mutableItems.count)")
            }
            #endif
        }
    }

    func summary() -> SyncOutboxSummary {
        stateQueue.sync {
            let pending = items.filter { $0.status == .queued || $0.status == .retrying || $0.status == .processing }.count
            let permanent = items.filter { $0.status == .permanentFailed }.count
            let lastError = items.reversed().compactMap(\.lastErrorCode).first
            return SyncOutboxSummary(pendingCount: pending, permanentFailureCount: permanent, lastErrorCode: lastError)
        }
    }

    @discardableResult
    func flush(using transport: SyncOutboxTransporting, now: Date = Date()) async -> SyncOutboxSummary {
        let nowTs = now.timeIntervalSince1970
        #if DEBUG
        print("[SyncOutbox] flush start now=\(nowTs)")
        #endif
        while let next = nextDispatchableItem(now: nowTs) {
            #if DEBUG
            print("[SyncOutbox] dispatch stage=\(next.stage.rawValue) session=\(next.walkSessionId) retry=\(next.retryCount)")
            #endif
            updateItem(id: next.id) { item in
                item.status = .processing
                item.updatedAt = Date().timeIntervalSince1970
            }

            let result = await transport.send(item: next)
            let currentNow = Date().timeIntervalSince1970
            switch result {
            case .success:
                #if DEBUG
                print("[SyncOutbox] success stage=\(next.stage.rawValue) session=\(next.walkSessionId)")
                #endif
                updateItem(id: next.id) { item in
                    item.status = .completed
                    item.lastErrorCode = nil
                    item.updatedAt = currentNow
                }
            case .retryable(let code):
                #if DEBUG
                print("[SyncOutbox] retryable stage=\(next.stage.rawValue) session=\(next.walkSessionId) code=\(code.rawValue)")
                #endif
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
                #if DEBUG
                print("[SyncOutbox] permanent-failed stage=\(next.stage.rawValue) session=\(next.walkSessionId) code=\(code.rawValue)")
                #endif
                updateItem(id: next.id) { item in
                    item.status = .permanentFailed
                    item.lastErrorCode = code
                    item.updatedAt = currentNow
                }
                if code == .notConfigured {
                    continue
                }
                return summary()
            }
        }
        return summary()
    }

    func requeuePermanentFailures(walkSessionIds: Set<String>? = nil) {
        stateQueue.sync {
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
        }
    }

    private static func retryDelay(retryCount: Int) -> TimeInterval {
        let exp = pow(2.0, Double(max(0, retryCount)))
        return min(900.0, 5.0 * exp)
    }

    private func nextDispatchableItem(now: TimeInterval) -> SyncOutboxItem? {
        stateQueue.sync {
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
    }

    private func updateItem(id: String, _ block: (inout SyncOutboxItem) -> Void) {
        stateQueue.sync {
            if let idx = items.firstIndex(where: { $0.id == id }) {
                block(&items[idx])
                persistLocked()
            }
        }
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


