import Foundation
import CoreLocation

struct SupabaseRuntimeConfig: Equatable {
    let baseURL: URL
    let anonKey: String

    static func load(
        env: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> SupabaseRuntimeConfig? {
        let urlString = env["SUPABASE_URL"] ?? bundle.supabaseStringValue(forInfoDictionaryKey: "SUPABASE_URL")
        let anonKey = env["SUPABASE_ANON_KEY"] ?? bundle.supabaseStringValue(forInfoDictionaryKey: "SUPABASE_ANON_KEY")

        guard let urlString, let baseURL = URL(string: urlString),
              let anonKey, anonKey.isEmpty == false else {
            return nil
        }
        return SupabaseRuntimeConfig(baseURL: baseURL, anonKey: anonKey)
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum SupabaseEndpoint {
    case function(name: String)
    case rest(path: String, query: String? = nil)

    func resolveURL(baseURL: URL) -> URL {
        switch self {
        case .function(let name):
            return baseURL
                .appendingPathComponent("functions", isDirectory: true)
                .appendingPathComponent("v1", isDirectory: true)
                .appendingPathComponent(name, isDirectory: false)
        case .rest(let path, let query):
            var components = URLComponents(
                url: baseURL
                    .appendingPathComponent("rest", isDirectory: true)
                    .appendingPathComponent("v1", isDirectory: true)
                    .appendingPathComponent(path, isDirectory: false),
                resolvingAgainstBaseURL: false
            )
            components?.percentEncodedQuery = query
            return components?.url
                ?? baseURL
                    .appendingPathComponent("rest", isDirectory: true)
                    .appendingPathComponent("v1", isDirectory: true)
                    .appendingPathComponent(path, isDirectory: false)
        }
    }
}

enum SupabaseHTTPError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case invalidBody
    case invalidResponse
    case unexpectedStatusCode(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase 설정이 누락되어 있습니다."
        case .invalidURL:
            return "Supabase URL이 올바르지 않습니다."
        case .invalidBody:
            return "요청 본문 인코딩에 실패했습니다."
        case .invalidResponse:
            return "응답 디코딩에 실패했습니다."
        case .unexpectedStatusCode(let code):
            return "Supabase 요청 실패(\(code))"
        }
    }
}

struct SupabaseHTTPClient {
    static let live = SupabaseHTTPClient()

    private let session: URLSession
    private let configLoader: () -> SupabaseRuntimeConfig?

    init(
        session: URLSession = .shared,
        configLoader: @escaping () -> SupabaseRuntimeConfig? = { SupabaseRuntimeConfig.load() }
    ) {
        self.session = session
        self.configLoader = configLoader
    }

    func request<T: Encodable>(
        _ endpoint: SupabaseEndpoint,
        method: HTTPMethod,
        body: T?
    ) async throws -> Data {
        let bodyData: Data?
        if let body {
            bodyData = try JSONEncoder().encode(body)
        } else {
            bodyData = nil
        }
        return try await request(endpoint, method: method, bodyData: bodyData)
    }

    func request(
        _ endpoint: SupabaseEndpoint,
        method: HTTPMethod,
        bodyData: Data?
    ) async throws -> Data {
        guard let config = configLoader() else {
            throw SupabaseHTTPError.notConfigured
        }

        let url = endpoint.resolveURL(baseURL: config.baseURL)
        guard url.absoluteString.isEmpty == false else {
            throw SupabaseHTTPError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            throw SupabaseHTTPError.invalidResponse
        }
        guard (200..<300).contains(statusCode) else {
            throw SupabaseHTTPError.unexpectedStatusCode(statusCode)
        }
        return data
    }
}

enum SupabaseISO8601 {
    private static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parseEpoch(_ value: String?) -> TimeInterval? {
        guard let value, value.isEmpty == false else { return nil }
        if let date = withFractional.date(from: value) ?? basic.date(from: value) {
            return date.timeIntervalSince1970
        }
        return nil
    }
}

protocol FeatureFlagRemoteServiceProtocol {
    func post(payload: [String: Any]) async throws -> Data
    func postFireAndForget(payload: [String: Any])
}

protocol WalkSyncServiceProtocol: SyncOutboxTransporting {
    func fetchBackfillValidationSummary(sessionIds: [String]) async -> SyncBackfillValidationSummary?
}

protocol ProfileSyncServiceProtocol: ProfileSyncOutboxTransporting {}

protocol NearbyPresenceServiceProtocol {
    func setVisibility(userId: String, enabled: Bool) async throws
    func upsertPresence(userId: String, latitude: Double, longitude: Double) async throws
    func getHotspots(userId: String?, centerLatitude: Double, centerLongitude: Double, radiusKm: Double) async throws -> [NearbyHotspotDTO]
}

protocol CaricatureServiceProtocol {
    func requestCaricature(
        petId: String,
        userId: String?,
        sourceImagePath: String?,
        sourceImageURL: String?,
        style: String,
        providerHint: String,
        requestId: String
    ) async throws -> CaricatureEdgeClient.ResponseDTO
}

protocol AreaReferenceServiceProtocol {
    func fetchSnapshot() async -> AreaReferenceSnapshot
}

struct FeatureControlService: FeatureFlagRemoteServiceProtocol {
    static let shared = FeatureControlService()

    private let client: SupabaseHTTPClient

    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    func post(payload: [String: Any]) async throws -> Data {
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await client.request(
            .function(name: "feature-control"),
            method: .post,
            bodyData: body
        )
    }

    func postFireAndForget(payload: [String: Any]) {
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        Task.detached(priority: .utility) {
            _ = try? await client.request(
                .function(name: "feature-control"),
                method: .post,
                bodyData: body
            )
        }
    }
}

struct CaricatureEdgeClient: CaricatureServiceProtocol {
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
        case invalidResponse
        case requestFailed(code: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Supabase 설정이 누락되어 캐리커처 요청을 보낼 수 없습니다."
            case .invalidResponse:
                return "캐리커처 응답을 해석할 수 없습니다."
            case .requestFailed(_, let message):
                return message
            }
        }
    }

    private let client: SupabaseHTTPClient

    init(client: SupabaseHTTPClient = .live) {
        self.client = client
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

        do {
            let data = try await client.request(
                .function(name: "caricature"),
                method: .post,
                body: payload
            )
            guard let decoded = try? JSONDecoder().decode(ResponseDTO.self, from: data) else {
                throw RequestError.invalidResponse
            }
            return decoded
        } catch let error as SupabaseHTTPError {
            switch error {
            case .notConfigured:
                throw RequestError.notConfigured
            case .unexpectedStatusCode(let code):
                throw RequestError.requestFailed(code: code, message: "캐리커처 생성 실패(\(code)).")
            default:
                throw RequestError.invalidResponse
            }
        }
    }
}

struct SupabaseSyncOutboxTransport: WalkSyncServiceProtocol {
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

    private struct SyncStageResponseDTO: Decodable {
        let seasonScoreSummary: SeasonScoreSummaryDTO?

        enum CodingKeys: String, CodingKey {
            case seasonScoreSummary = "season_score_summary"
        }
    }

    private struct SeasonScoreSummaryDTO: Decodable {
        let catchupBonus: Double?
        let catchupBuffActive: Bool?
        let catchupBuffGrantedAt: String?
        let catchupBuffExpiresAt: String?
        let explain: ExplainDTO?

        enum CodingKeys: String, CodingKey {
            case catchupBonus = "catchup_bonus"
            case catchupBuffActive = "catchup_buff_active"
            case catchupBuffGrantedAt = "catchup_buff_granted_at"
            case catchupBuffExpiresAt = "catchup_buff_expires_at"
            case explain
        }
    }

    private struct ExplainDTO: Decodable {
        let uiReason: String?
        let catchupBuff: CatchupBuffDTO?

        enum CodingKeys: String, CodingKey {
            case uiReason = "ui_reason"
            case catchupBuff = "catchup_buff"
        }
    }

    private struct CatchupBuffDTO: Decodable {
        let status: String?
        let blockReason: String?
        let grantedAt: String?
        let expiresAt: String?
        let bonusScore: Double?

        enum CodingKeys: String, CodingKey {
            case status
            case blockReason = "block_reason"
            case grantedAt = "granted_at"
            case expiresAt = "expires_at"
            case bonusScore = "bonus_score"
        }
    }

    private let client: SupabaseHTTPClient

    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    func send(item: SyncOutboxItem) async -> SyncOutboxSendResult {
        guard AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) else {
            return .retryable(.unauthorized)
        }

        let body: [String: Any] = [
            "action": "sync_walk_stage",
            "walk_session_id": item.walkSessionId,
            "stage": item.stage.rawValue,
            "idempotency_key": item.idempotencyKey,
            "payload": item.payload
        ]

        do {
            let data = try await client.request(
                .function(name: "sync-walk"),
                method: .post,
                bodyData: try JSONSerialization.data(withJSONObject: body)
            )
            persistSeasonCatchupBuffSnapshotIfNeeded(item: item, data: data)
            return .success
        } catch let error as SupabaseHTTPError {
            switch error {
            case .notConfigured:
                return .retryable(.notConfigured)
            case .unexpectedStatusCode(let statusCode):
                switch statusCode {
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
        let normalized = sessionIds
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.isEmpty == false }
        guard normalized.isEmpty == false else {
            return SyncBackfillValidationSummary(sessionCount: 0, pointCount: 0, totalAreaM2: 0, totalDurationSec: 0)
        }

        let body: [String: Any] = [
            "action": "validate_backfill",
            "session_ids": normalized
        ]

        guard let data = try? await client.request(
            .function(name: "sync-walk"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: body)
        ) else {
            return nil
        }

        guard let decoded = try? JSONDecoder().decode(BackfillSummaryResponseDTO.self, from: data),
              let summary = decoded.summary else {
            return nil
        }

        return SyncBackfillValidationSummary(
            sessionCount: summary.sessionCount,
            pointCount: summary.pointCount,
            totalAreaM2: summary.totalAreaM2,
            totalDurationSec: summary.totalDurationSec
        )
    }

    private func persistSeasonCatchupBuffSnapshotIfNeeded(item: SyncOutboxItem, data: Data) {
        guard item.stage == .points else { return }
        guard let decoded = try? JSONDecoder().decode(SyncStageResponseDTO.self, from: data),
              let season = decoded.seasonScoreSummary else {
            return
        }

        let catchup = season.explain?.catchupBuff
        let status = SeasonCatchupBuffDisplayStatus(rawValue: catchup?.status ?? "")
            ?? (season.catchupBuffActive == true ? .active : .inactive)
        let snapshot = SeasonCatchupBuffSnapshot(
            walkSessionId: item.walkSessionId,
            status: status,
            isActive: season.catchupBuffActive ?? false,
            bonusScore: season.catchupBonus ?? catchup?.bonusScore ?? 0,
            uiReason: season.explain?.uiReason,
            blockReason: catchup?.blockReason,
            grantedAt: SupabaseISO8601.parseEpoch(season.catchupBuffGrantedAt ?? catchup?.grantedAt),
            expiresAt: SupabaseISO8601.parseEpoch(season.catchupBuffExpiresAt ?? catchup?.expiresAt),
            syncedAt: Date().timeIntervalSince1970
        )
        UserdefaultSetting.shared.updateSeasonCatchupBuffSnapshot(snapshot)
    }
}

struct SupabaseProfileSyncTransport: ProfileSyncServiceProtocol {
    private let client: SupabaseHTTPClient

    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    func send(item: ProfileSyncOutboxItem) async -> SyncOutboxSendResult {
        guard AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) else {
            return .retryable(.unauthorized)
        }

        var body: [String: Any] = [
            "action": "sync_profile_stage",
            "stage": item.stage.rawValue,
            "user_id": item.userId,
            "idempotency_key": item.idempotencyKey,
            "payload": item.payload
        ]
        body["pet_id"] = item.petId ?? NSNull()

        do {
            _ = try await client.request(
                .function(name: "sync-profile"),
                method: .post,
                bodyData: try JSONSerialization.data(withJSONObject: body)
            )
            return .success
        } catch let error as SupabaseHTTPError {
            switch error {
            case .notConfigured:
                return .retryable(.notConfigured)
            case .unexpectedStatusCode(let statusCode):
                switch statusCode {
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

struct NearbyPresenceService: NearbyPresenceServiceProtocol {
    private struct ResponseHotspotDTO: Decodable {
        let geohash7: String
        let count: Int
        let intensity: Double
        let center_lat: Double
        let center_lng: Double
    }

    private struct HotspotEnvelope: Decodable {
        let hotspots: [ResponseHotspotDTO]
    }

    private let client: SupabaseHTTPClient

    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    func setVisibility(userId: String, enabled: Bool) async throws {
        let body: [String: Any] = [
            "action": "set_visibility",
            "userId": userId,
            "enabled": enabled
        ]
        _ = try await client.request(
            .function(name: "nearby-presence"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: body)
        )
    }

    func upsertPresence(userId: String, latitude: Double, longitude: Double) async throws {
        let body: [String: Any] = [
            "action": "upsert_presence",
            "userId": userId,
            "lat": latitude,
            "lng": longitude
        ]
        _ = try await client.request(
            .function(name: "nearby-presence"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: body)
        )
    }

    func getHotspots(
        userId: String?,
        centerLatitude: Double,
        centerLongitude: Double,
        radiusKm: Double
    ) async throws -> [NearbyHotspotDTO] {
        var payload: [String: Any] = [
            "action": "get_hotspots",
            "centerLat": centerLatitude,
            "centerLng": centerLongitude,
            "radiusKm": radiusKm
        ]
        if let userId, userId.isEmpty == false {
            payload["userId"] = userId
        }

        let data = try await client.request(
            .function(name: "nearby-presence"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )

        let decoded = try JSONDecoder().decode(HotspotEnvelope.self, from: data)
        return decoded.hotspots.map {
            NearbyHotspotDTO(
                geohash: $0.geohash7,
                count: $0.count,
                intensity: max(0.0, min(1.0, $0.intensity)),
                centerCoordinate: CLLocationCoordinate2D(latitude: $0.center_lat, longitude: $0.center_lng)
            )
        }
    }
}

final class SupabaseAreaReferenceRepository: AreaReferenceRepository, AreaReferenceServiceProtocol {
    static let shared = SupabaseAreaReferenceRepository()

    private let client: SupabaseHTTPClient

    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    func fetchSnapshot() async -> AreaReferenceSnapshot {
        do {
            let catalogsData = try await client.request(
                .rest(
                    path: "area_reference_catalogs",
                    query: "select=id,code,name,sort_order,is_active&is_active=eq.true&order=sort_order.asc"
                ),
                method: .get,
                body: Optional<String>.none
            )
            let referencesData = try await client.request(
                .rest(
                    path: "area_references",
                    query: "select=id,catalog_id,reference_name,area_m2,is_featured,display_order,is_active&is_active=eq.true&order=display_order.asc,area_m2.desc"
                ),
                method: .get,
                body: Optional<String>.none
            )
            let decoder = JSONDecoder()
            let catalogs = try decoder.decode([AreaReferenceCatalogDTO].self, from: catalogsData)
            let references = try decoder.decode([AreaReferenceRowDTO].self, from: referencesData)
            let snapshot = makeRemoteSnapshot(catalogs: catalogs, references: references)
            return snapshot.allAreas.isEmpty ? fallbackSnapshot() : snapshot
        } catch {
            return fallbackSnapshot()
        }
    }

    private func makeRemoteSnapshot(
        catalogs: [AreaReferenceCatalogDTO],
        references: [AreaReferenceRowDTO]
    ) -> AreaReferenceSnapshot {
        let activeCatalogIds = Set(catalogs.map(\.id))
        let filteredReferences = references.filter { activeCatalogIds.contains($0.catalogId) }
        let items = filteredReferences.map {
            AreaReferenceItem(
                id: $0.id,
                catalogId: $0.catalogId,
                referenceName: $0.referenceName,
                areaM2: $0.areaM2,
                isFeatured: $0.isFeatured,
                displayOrder: $0.displayOrder
            )
        }

        let sections = catalogs
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.code < rhs.code
                }
                return lhs.sortOrder < rhs.sortOrder
            }
            .map { catalog in
                let sectionItems = items
                    .filter { $0.catalogId == catalog.id }
                    .sorted { lhs, rhs in
                        if lhs.isFeatured == rhs.isFeatured {
                            if lhs.displayOrder == rhs.displayOrder {
                                return lhs.areaM2 > rhs.areaM2
                            }
                            return lhs.displayOrder < rhs.displayOrder
                        }
                        return lhs.isFeatured && !rhs.isFeatured
                    }
                return AreaReferenceSection(
                    id: catalog.id,
                    catalogCode: catalog.code,
                    catalogName: catalog.name,
                    sortOrder: catalog.sortOrder,
                    references: sectionItems
                )
            }
            .filter { $0.references.isEmpty == false }

        let allAreas = items
            .map { AreaMeter($0.referenceName, $0.areaM2) }
            .sorted { $0.area > $1.area }

        let featuredAreas = items
            .filter(\.isFeatured)
            .map { AreaMeter($0.referenceName, $0.areaM2) }
            .sorted { $0.area > $1.area }

        return AreaReferenceSnapshot(
            source: .remote,
            allAreas: allAreas,
            featuredAreas: featuredAreas,
            sections: sections
        )
    }

    private func fallbackSnapshot() -> AreaReferenceSnapshot {
        let legacy = AreaMeterCollection().areas
        let legacyItems = legacy.enumerated().map { index, area in
            AreaReferenceItem(
                id: "fallback-\(index)",
                catalogId: "legacy",
                referenceName: area.areaName,
                areaM2: area.area,
                isFeatured: index < 10,
                displayOrder: index
            )
        }

        return AreaReferenceSnapshot(
            source: .fallback,
            allAreas: legacy,
            featuredAreas: Array(legacy.prefix(10)),
            sections: [
                AreaReferenceSection(
                    id: "legacy",
                    catalogCode: "legacy",
                    catalogName: "로컬 비교군 (Fallback)",
                    sortOrder: 0,
                    references: legacyItems
                )
            ]
        )
    }
}

private extension Bundle {
    func supabaseStringValue(forInfoDictionaryKey key: String) -> String? {
        guard let value = object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum SupabaseAssetError: LocalizedError {
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "이미지 업로드 응답이 올바르지 않습니다."
        case .serverError(let message):
            return message
        }
    }
}

final class DeviceAppleCredentialAuthService: AppleCredentialAuthServiceProtocol {
    static let shared = DeviceAppleCredentialAuthService()

    func signInWithApple(identityToken: String) async throws {
        if identityToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SupabaseAssetError.serverError("Apple identity token is missing.")
        }
    }
}

private struct UploadProfileImageRequestDTO: Encodable {
    let ownerId: String
    let imageBase64: String
    let imageKind: String
}

private struct UploadProfileImageResponseDTO: Decodable {
    let publicUrl: String?
    let error: String?
}

final class SupabaseProfileImageRepository: ProfileImageRepository {
    static let shared = SupabaseProfileImageRepository()
    private let client: SupabaseHTTPClient

    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    func uploadUserProfileImage(data: Data, ownerId: String) async throws -> String {
        try await upload(data: data, ownerId: ownerId, imageKind: "user")
    }

    func uploadPetProfileImage(data: Data, ownerId: String) async throws -> String {
        try await upload(data: data, ownerId: ownerId, imageKind: "pet")
    }

    private func upload(data: Data, ownerId: String, imageKind: String) async throws -> String {
        let safeOwnerId = ownerId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
        let requestBody = UploadProfileImageRequestDTO(
            ownerId: safeOwnerId,
            imageBase64: data.base64EncodedString(),
            imageKind: imageKind
        )
        let responseData = try await client.request(
            .function(name: "upload-profile-image"),
            method: .post,
            body: requestBody
        )
        let decoded = try JSONDecoder().decode(UploadProfileImageResponseDTO.self, from: responseData)
        if let url = decoded.publicUrl, url.isEmpty == false {
            return url
        }
        if let message = decoded.error, message.isEmpty == false {
            throw SupabaseAssetError.serverError(message)
        }
        throw SupabaseAssetError.invalidResponse
    }
}
