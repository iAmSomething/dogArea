import Foundation
import CryptoKit

enum AppFeatureFlagKey: String, CaseIterable {
    case heatmapV1 = "ff_heatmap_v1"
    case caricatureAsyncV1 = "ff_caricature_async_v1"
    case nearbyHotspotV1 = "ff_nearby_hotspot_v1"
    case repoLayerV2 = "ff_repo_layer_v2"
    case supabaseReadV1 = "ff_supabase_read_v1"
    case coredataDeprecationV1 = "ff_coredata_deprecation_v1"
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

    /// 현재 앱 인스턴스 기준으로 특정 feature flag 활성 여부를 계산합니다.
    /// - Parameter key: 평가할 feature flag 키입니다.
    /// - Returns: 현재 인스턴스에 feature가 활성화되어 있으면 `true`입니다.
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

    /// 앱 인스턴스와 키를 조합해 일관된 롤아웃 버킷 값을 계산합니다.
    /// - Parameter key: 롤아웃 버킷 계산에 사용할 feature flag 키입니다.
    /// - Returns: 0 이상 99 이하의 버킷 값입니다.
    private func rolloutBucket(for key: String) -> Int {
        let seed = "\(appInstance):\(key)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        guard let first = Array(digest).first else { return 0 }
        return Int(first) % 100
    }

    /// 앱 인스턴스 식별자를 로드하거나 신규 생성합니다.
    /// - Parameter storageKey: 앱 인스턴스 식별자를 저장할 UserDefaults 키입니다.
    /// - Returns: 현재 앱 인스턴스 식별자입니다.
    private static func loadOrCreateAppInstance(storageKey: String) -> String {
        if let existing = UserDefaults.standard.string(forKey: storageKey), existing.isEmpty == false {
            return existing
        }
        let generated = UUID().uuidString.lowercased()
        UserDefaults.standard.set(generated, forKey: storageKey)
        return generated
    }

    /// 캐시된 feature flag를 로컬 저장소에서 복원합니다.
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

    /// 현재 캐시된 feature flag를 로컬 저장소에 기록합니다.
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
