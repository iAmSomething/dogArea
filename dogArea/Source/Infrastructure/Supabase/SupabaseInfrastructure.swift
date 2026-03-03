import Foundation
import CoreLocation
#if canImport(WidgetKit)
import WidgetKit
#endif

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
    case auth(path: String, query: String? = nil)

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
        case .auth(let path, let query):
            var components = URLComponents(
                url: baseURL
                    .appendingPathComponent("auth", isDirectory: true)
                    .appendingPathComponent("v1", isDirectory: true)
                    .appendingPathComponent(path, isDirectory: false),
                resolvingAgainstBaseURL: false
            )
            components?.percentEncodedQuery = query
            return components?.url
                ?? baseURL
                    .appendingPathComponent("auth", isDirectory: true)
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

private struct SupabaseAuthUserDTO: Decodable {
    let id: String?
    let email: String?
}

private struct SupabaseAuthResponseDTO: Decodable {
    let user: SupabaseAuthUserDTO?
    let id: String?
    let email: String?
    let message: String?
    let error: String?
    let errorDescription: String?
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let expiresAt: TimeInterval?
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case user
        case id
        case email
        case message
        case error
        case errorDescription = "error_description"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case tokenType = "token_type"
    }
}

private struct SupabaseRefreshTokenRequestDTO: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private enum SupabaseRefreshCredentialOutcome {
    case success(AuthCredentialResult)
    case retryableFailure
    case terminalFailure
}

private extension SupabaseAuthResponseDTO {
    /// 디코딩된 Auth 응답을 앱 인증 결과 모델로 변환합니다.
    /// - Parameters:
    ///   - fallbackEmail: 응답에 이메일이 없을 때 사용할 대체 이메일입니다.
    ///   - now: 토큰 만료시각 계산 기준 시각입니다.
    /// - Returns: 변환 가능한 경우 사용자 식별 정보와 세션 토큰을 반환합니다.
    func toCredentialResult(fallbackEmail: String?, now: Date) -> AuthCredentialResult? {
        let userId = user?.id ?? id
        guard let userId, userId.isEmpty == false else {
            return nil
        }
        let email = user?.email ?? email ?? fallbackEmail
        return AuthCredentialResult(
            identity: AuthenticatedUserIdentity(userId: userId, email: email),
            tokenSession: toTokenSession(now: now)
        )
    }

    /// 디코딩된 Auth 응답에서 토큰 세션을 계산합니다.
    /// - Parameter now: `expires_in` 기반 만료시각 계산 기준 시각입니다.
    /// - Returns: 토큰 필드가 모두 유효하면 `AuthTokenSession`을 반환합니다.
    func toTokenSession(now: Date) -> AuthTokenSession? {
        guard
            let accessToken,
            let refreshToken,
            let tokenType,
            accessToken.isEmpty == false,
            refreshToken.isEmpty == false,
            tokenType.isEmpty == false
        else {
            return nil
        }
        let resolvedExpiresAt: TimeInterval
        if let expiresAt {
            resolvedExpiresAt = expiresAt
        } else if let expiresIn {
            resolvedExpiresAt = now.timeIntervalSince1970 + TimeInterval(expiresIn)
        } else {
            return nil
        }
        guard resolvedExpiresAt > now.timeIntervalSince1970 else {
            return nil
        }
        return AuthTokenSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: resolvedExpiresAt,
            tokenType: tokenType
        )
    }
}

struct SupabaseHTTPClient {
    static let live = SupabaseHTTPClient()

    private let session: URLSession
    private let configLoader: () -> SupabaseRuntimeConfig?
    private let authSessionStore: AuthSessionStoreProtocol

    init(
        session: URLSession = .shared,
        configLoader: @escaping () -> SupabaseRuntimeConfig? = { SupabaseRuntimeConfig.load() },
        authSessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared
    ) {
        self.session = session
        self.configLoader = configLoader
        self.authSessionStore = authSessionStore
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
        request.setValue(await authorizationHeaderValue(config: config), forHTTPHeaderField: "Authorization")
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

    /// 현재 저장된 사용자 세션을 기준으로 Authorization 헤더 값을 계산합니다.
    /// - Parameter config: Supabase 런타임 기본 구성입니다.
    /// - Returns: 사용자 토큰이 유효하면 사용자 Bearer, 아니면 anon Bearer 값을 반환합니다.
    private func authorizationHeaderValue(config: SupabaseRuntimeConfig) async -> String {
        guard let accessToken = await validAccessToken(config: config) else {
            return "Bearer \(config.anonKey)"
        }
        return "Bearer \(accessToken)"
    }

    /// 저장된 access token의 유효성을 확인하고 필요 시 refresh를 수행합니다.
    /// - Parameter config: Supabase 런타임 기본 구성입니다.
    /// - Returns: 요청에 사용할 수 있는 access token 문자열 또는 `nil`입니다.
    private func validAccessToken(config: SupabaseRuntimeConfig) async -> String? {
        let now = Date().timeIntervalSince1970
        if let tokenSession = authSessionStore.currentTokenSession(),
           tokenSession.isValid(at: now) {
            return tokenSession.accessToken
        }
        guard let current = authSessionStore.currentTokenSession(),
              current.refreshToken.isEmpty == false else {
            return nil
        }
        let refreshOutcome = await refreshCredential(config: config, refreshToken: current.refreshToken)
        switch refreshOutcome {
        case .success(let refreshed):
            authSessionStore.persist(refreshed.identity)
            if let tokenSession = refreshed.tokenSession {
                authSessionStore.persist(tokenSession: tokenSession)
                return tokenSession.accessToken
            }
            authSessionStore.clearTokenSession()
            return nil
        case .retryableFailure:
            return nil
        case .terminalFailure:
            authSessionStore.clearTokenSession()
            return nil
        }
    }

    /// refresh token으로 새 세션 토큰을 발급받고 사용자 식별 정보를 복원합니다.
    /// - Parameters:
    ///   - config: Supabase 런타임 기본 구성입니다.
    ///   - refreshToken: 만료된 access token과 짝을 이루는 refresh token입니다.
    /// - Returns: refresh 성공/실패 성격(재시도 가능 여부 포함)을 반환합니다.
    private func refreshCredential(
        config: SupabaseRuntimeConfig,
        refreshToken: String
    ) async -> SupabaseRefreshCredentialOutcome {
        let endpoint = SupabaseEndpoint.auth(path: "token", query: "grant_type=refresh_token")
        let url = endpoint.resolveURL(baseURL: config.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(
            SupabaseRefreshTokenRequestDTO(refreshToken: refreshToken)
        )

        guard let (data, response) = try? await session.data(for: request),
              let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            return .retryableFailure
        }

        guard (200..<300).contains(statusCode) else {
            if statusCode == 400 || statusCode == 401 {
                return .terminalFailure
            }
            return .retryableFailure
        }

        guard let decoded = try? JSONDecoder().decode(SupabaseAuthResponseDTO.self, from: data),
              let credential = decoded.toCredentialResult(
                fallbackEmail: authSessionStore.currentIdentity()?.email,
                now: Date()
              ) else {
            return .terminalFailure
        }
        return .success(credential)
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

enum RivalLeaderboardPeriod: String, CaseIterable {
    case week
    case season
}

struct RivalLeaderboardEntryDTO: Identifiable, Equatable {
    let id: String
    let rank: Int
    let aliasCode: String
    let league: String
    let effectiveLeague: String
    let scoreBucket: String
    let isMe: Bool
}

protocol RivalLeagueServiceProtocol {
    func fetchLeaderboard(period: RivalLeaderboardPeriod, topN: Int) async throws -> [RivalLeaderboardEntryDTO]
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

struct TerritoryWidgetSummaryDTO: Equatable {
    let todayTileCount: Int
    let weeklyTileCount: Int
    let defenseScheduledTileCount: Int
    let scoreUpdatedAt: TimeInterval?
    let refreshedAt: TimeInterval
    let hasData: Bool
}

protocol TerritoryWidgetSummaryServiceProtocol {
    /// 위젯용 영역 요약 지표를 서버 RPC에서 조회합니다.
    /// - Parameter now: 서버 집계 기준 시각입니다.
    /// - Returns: 오늘/주간/방어 예정 타일과 갱신 시각을 포함한 요약 DTO입니다.
    func fetchSummary(now: Date) async throws -> TerritoryWidgetSummaryDTO
}

protocol TerritoryWidgetSnapshotSyncing {
    /// 서버 요약을 조회해 위젯 공유 스냅샷을 갱신합니다.
    /// - Parameters:
    ///   - force: `true`면 TTL을 무시하고 즉시 갱신합니다.
    ///   - now: TTL/상태 계산 기준 시각입니다.
    func sync(force: Bool, now: Date) async
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

struct RivalLeagueService: RivalLeagueServiceProtocol {
    private struct ResponseRowDTO: Decodable {
        let rankPosition: Int
        let aliasCode: String
        let league: String
        let effectiveLeague: String
        let scoreBucket: String
        let isMe: Bool

        enum CodingKeys: String, CodingKey {
            case rankPosition = "rank_position"
            case aliasCode = "alias_code"
            case league
            case effectiveLeague = "effective_league"
            case scoreBucket = "score_bucket"
            case isMe = "is_me"
        }
    }

    private let client: SupabaseHTTPClient

    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    /// 점수 원문 대신 점수 버킷을 제공하는 익명 리더보드 데이터를 조회합니다.
    func fetchLeaderboard(period: RivalLeaderboardPeriod, topN: Int = 20) async throws -> [RivalLeaderboardEntryDTO] {
        let safeTopN = max(1, min(topN, 200))
        let payload: [String: Any] = [
            "period_type": period.rawValue,
            "top_n": safeTopN,
            "now_ts": ISO8601DateFormatter().string(from: Date())
        ]
        let data = try await client.request(
            .rest(path: "rpc/rpc_get_rival_leaderboard"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )
        let rows = try JSONDecoder().decode([ResponseRowDTO].self, from: data)
        return rows.map { row in
            RivalLeaderboardEntryDTO(
                id: "\(period.rawValue)-\(row.rankPosition)-\(row.aliasCode)",
                rank: row.rankPosition,
                aliasCode: row.aliasCode,
                league: row.league,
                effectiveLeague: row.effectiveLeague,
                scoreBucket: row.scoreBucket,
                isMe: row.isMe
            )
        }
    }
}

struct TerritoryWidgetSummaryService: TerritoryWidgetSummaryServiceProtocol {
    private struct ResponseDTO: Decodable {
        let todayTileCount: Int?
        let weeklyTileCount: Int?
        let defenseScheduledTileCount: Int?
        let scoreUpdatedAt: String?
        let refreshedAt: String?
        let hasData: Bool?

        enum CodingKeys: String, CodingKey {
            case todayTileCount = "today_tile_count"
            case weeklyTileCount = "weekly_tile_count"
            case defenseScheduledTileCount = "defense_scheduled_tile_count"
            case scoreUpdatedAt = "score_updated_at"
            case refreshedAt = "refreshed_at"
            case hasData = "has_data"
        }
    }

    private let client: SupabaseHTTPClient

    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    /// 위젯용 영역 요약 지표를 서버 RPC에서 조회합니다.
    /// - Parameter now: 서버 집계 기준 시각입니다.
    /// - Returns: 오늘/주간/방어 예정 타일과 갱신 시각을 포함한 요약 DTO입니다.
    func fetchSummary(now: Date) async throws -> TerritoryWidgetSummaryDTO {
        let payload: [String: Any] = [
            "now_ts": ISO8601DateFormatter().string(from: now)
        ]
        let data = try await client.request(
            .rest(path: "rpc/rpc_get_widget_territory_summary"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )
        let decoded = try JSONDecoder().decode(ResponseDTO.self, from: data)
        let refreshedAt = SupabaseISO8601.parseEpoch(decoded.refreshedAt) ?? now.timeIntervalSince1970
        let summary = TerritoryWidgetSummaryDTO(
            todayTileCount: max(0, decoded.todayTileCount ?? 0),
            weeklyTileCount: max(0, decoded.weeklyTileCount ?? 0),
            defenseScheduledTileCount: max(0, decoded.defenseScheduledTileCount ?? 0),
            scoreUpdatedAt: SupabaseISO8601.parseEpoch(decoded.scoreUpdatedAt),
            refreshedAt: refreshedAt,
            hasData: decoded.hasData
                ?? ((decoded.weeklyTileCount ?? 0) > 0 || (decoded.todayTileCount ?? 0) > 0)
        )
        return summary
    }
}

final class DefaultTerritoryWidgetSnapshotSyncService: TerritoryWidgetSnapshotSyncing {
    private let summaryService: TerritoryWidgetSummaryServiceProtocol
    private let snapshotStore: TerritoryWidgetSnapshotStoring
    private let userSessionStore: UserSessionStoreProtocol
    private let preferenceStore: UserDefaults
    private let syncTTL: TimeInterval
    private let staleGraceInterval: TimeInterval

    /// 영역 위젯 스냅샷 동기화 서비스를 생성합니다.
    /// - Parameters:
    ///   - summaryService: 서버 요약 RPC 호출 서비스입니다.
    ///   - snapshotStore: 앱 그룹 기반 위젯 스냅샷 저장소입니다.
    ///   - userSessionStore: 현재 로그인 사용자 컨텍스트 조회 저장소입니다.
    ///   - preferenceStore: 마지막 동기화 메타데이터를 저장할 기본 설정 저장소입니다.
    ///   - syncTTL: RPC 재조회 최소 간격(초)입니다.
    ///   - staleGraceInterval: 오프라인 캐시를 허용할 최대 유예 시간(초)입니다.
    init(
        summaryService: TerritoryWidgetSummaryServiceProtocol = TerritoryWidgetSummaryService(),
        snapshotStore: TerritoryWidgetSnapshotStoring = DefaultTerritoryWidgetSnapshotStore.shared,
        userSessionStore: UserSessionStoreProtocol = DefaultUserSessionStore.shared,
        preferenceStore: UserDefaults = .standard,
        syncTTL: TimeInterval = 15 * 60,
        staleGraceInterval: TimeInterval = 6 * 60 * 60
    ) {
        self.summaryService = summaryService
        self.snapshotStore = snapshotStore
        self.userSessionStore = userSessionStore
        self.preferenceStore = preferenceStore
        self.syncTTL = syncTTL
        self.staleGraceInterval = staleGraceInterval
    }

    /// 서버 요약을 조회해 위젯 공유 스냅샷을 갱신합니다.
    /// - Parameters:
    ///   - force: `true`면 TTL을 무시하고 즉시 갱신합니다.
    ///   - now: TTL/상태 계산 기준 시각입니다.
    func sync(force: Bool, now: Date) async {
        guard shouldSync(force: force, now: now) else { return }

        guard let user = userSessionStore.currentUserInfo(),
              user.id.isEmpty == false else {
            saveGuestSnapshot(now: now)
            return
        }

        do {
            let summary = try await summaryService.fetchSummary(now: now)
            saveMemberSnapshot(summary: summary, now: now)
        } catch {
            saveFailureSnapshot(now: now)
        }
    }

    /// TTL과 이전 상태를 기준으로 이번 동기화를 수행할지 판단합니다.
    /// - Parameters:
    ///   - force: `true`면 즉시 동기화합니다.
    ///   - now: 판단 기준 시각입니다.
    /// - Returns: 동기화가 필요하면 `true`, 스킵 가능하면 `false`입니다.
    private func shouldSync(force: Bool, now: Date) -> Bool {
        if force { return true }
        let snapshot = snapshotStore.load()
        let age = now.timeIntervalSince1970 - snapshot.updatedAt
        return age >= syncTTL
    }

    /// 비회원 상태 스냅샷을 저장합니다.
    /// - Parameter now: 저장 시각입니다.
    private func saveGuestSnapshot(now: Date) {
        let snapshot = TerritoryWidgetSnapshot(
            status: .guestLocked,
            message: "로그인 후 오늘/주간 영역 현황을 위젯에서 확인할 수 있어요.",
            summary: nil,
            updatedAt: now.timeIntervalSince1970
        )
        save(snapshot, now: now)
    }

    /// 서버 요약 응답을 회원 상태 스냅샷으로 저장합니다.
    /// - Parameters:
    ///   - summary: 서버에서 조회한 최신 영역 요약 DTO입니다.
    ///   - now: 저장 시각입니다.
    private func saveMemberSnapshot(summary: TerritoryWidgetSummaryDTO, now: Date) {
        let snapshotStatus: TerritoryWidgetSnapshotStatus = summary.hasData ? .memberReady : .emptyData
        let snapshotMessage: String = summary.hasData
            ? "오늘/주간/방어 예정 지표를 표시합니다."
            : "아직 집계된 타일이 없어요. 첫 산책을 시작해보세요."

        let snapshot = TerritoryWidgetSnapshot(
            status: snapshotStatus,
            message: snapshotMessage,
            summary: TerritoryWidgetSummarySnapshot(
                todayTileCount: summary.todayTileCount,
                weeklyTileCount: summary.weeklyTileCount,
                defenseScheduledTileCount: summary.defenseScheduledTileCount,
                scoreUpdatedAt: summary.scoreUpdatedAt,
                refreshedAt: summary.refreshedAt
            ),
            updatedAt: now.timeIntervalSince1970
        )
        save(snapshot, now: now)
    }

    /// 서버 조회 실패 시 마지막 성공 스냅샷 기반 상태로 저장합니다.
    /// - Parameter now: 저장 시각입니다.
    private func saveFailureSnapshot(now: Date) {
        let current = snapshotStore.load()
        let cachedSummary = current.summary

        if let cachedSummary {
            let cacheAge = now.timeIntervalSince1970 - cachedSummary.refreshedAt
            let status: TerritoryWidgetSnapshotStatus = cacheAge <= staleGraceInterval ? .offlineCached : .syncDelayed
            let message: String = cacheAge <= staleGraceInterval
                ? "오프라인 상태예요. 마지막 성공 스냅샷을 표시 중입니다."
                : "동기화가 지연되고 있어요. 앱을 열어 최신화해주세요."
            save(
                TerritoryWidgetSnapshot(
                    status: status,
                    message: message,
                    summary: cachedSummary,
                    updatedAt: now.timeIntervalSince1970
                ),
                now: now
            )
            return
        }

        save(
            TerritoryWidgetSnapshot(
                status: .syncDelayed,
                message: "데이터를 아직 불러오지 못했어요. 앱을 열어 동기화해주세요.",
                summary: nil,
                updatedAt: now.timeIntervalSince1970
            ),
            now: now
        )
    }

    /// 위젯 스냅샷 저장 후 재로딩을 요청하고 마지막 동기화 시각을 기록합니다.
    /// - Parameters:
    ///   - snapshot: 저장할 영역 위젯 스냅샷입니다.
    ///   - now: 마지막 동기화 시각 기록 기준입니다.
    private func save(_ snapshot: TerritoryWidgetSnapshot, now: Date) {
        snapshotStore.save(snapshot)
        preferenceStore.set(now.timeIntervalSince1970, forKey: "territory.widget.lastSyncAt.v1")
        reloadTerritoryWidgetTimeline()
    }

    /// WidgetKit 타임라인을 즉시 재요청해 최신 스냅샷이 반영되도록 합니다.
    private func reloadTerritoryWidgetTimeline() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: WalkWidgetBridgeContract.territoryWidgetKind)
        #endif
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
                    query: "select=id,catalog_id,reference_name,area_m2,is_featured,display_order,is_active&is_active=eq.true&order=display_order.asc,area_m2.asc"
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
                        if lhs.displayOrder == rhs.displayOrder {
                            if lhs.areaM2 == rhs.areaM2 {
                                return lhs.referenceName < rhs.referenceName
                            }
                            return lhs.areaM2 < rhs.areaM2
                        }
                        return lhs.displayOrder < rhs.displayOrder
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
            .sorted { $0.area < $1.area }

        let featuredAreas = items
            .filter(\.isFeatured)
            .map { AreaMeter($0.referenceName, $0.areaM2) }
            .sorted { $0.area < $1.area }

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
                isFeatured: index >= max(legacy.count - 10, 0),
                displayOrder: index
            )
        }

        return AreaReferenceSnapshot(
            source: .fallback,
            allAreas: legacy,
            featuredAreas: Array(legacy.suffix(10)),
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

enum SupabaseAuthError: LocalizedError {
    case notConfigured
    case invalidCredentials
    case userAlreadyExists
    case responseDecodeFailed
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase 설정이 누락되어 로그인할 수 없습니다."
        case .invalidCredentials:
            return "이메일 또는 비밀번호가 올바르지 않습니다."
        case .userAlreadyExists:
            return "이미 가입된 이메일입니다. 로그인을 시도해주세요."
        case .responseDecodeFailed:
            return "인증 응답을 해석하지 못했습니다."
        case .requestFailed(let message):
            return message
        }
    }
}

final class DeviceAppleCredentialAuthService: AppleCredentialAuthServiceProtocol {
    static let shared = DeviceAppleCredentialAuthService()

    /// Apple 로그인 토큰의 최소 유효성(빈 값 여부)을 확인합니다.
    func signInWithApple(identityToken: String) async throws {
        if identityToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SupabaseAssetError.serverError("Apple identity token is missing.")
        }
    }

    /// Supabase Auth `token?grant_type=password` 엔드포인트로 이메일 로그인을 수행합니다.
    /// - Parameters:
    ///   - email: 로그인 이메일입니다.
    ///   - password: 로그인 비밀번호입니다.
    /// - Returns: 사용자 식별 정보와 선택적 토큰 세션입니다.
    func signInWithEmail(email: String, password: String) async throws -> AuthCredentialResult {
        let payload = [
            "email": email,
            "password": password
        ]
        return try await requestAuthIdentity(path: "token", query: "grant_type=password", payload: payload)
    }

    /// Supabase Auth `signup` 엔드포인트로 이메일 회원가입을 수행합니다.
    /// - Parameters:
    ///   - email: 회원가입 이메일입니다.
    ///   - password: 회원가입 비밀번호입니다.
    /// - Returns: 사용자 식별 정보와 선택적 토큰 세션입니다.
    func signUpWithEmail(email: String, password: String) async throws -> AuthCredentialResult {
        let payload = [
            "email": email,
            "password": password
        ]
        return try await requestAuthIdentity(path: "signup", query: nil, payload: payload)
    }

    /// 공통 Auth 요청을 수행하고 응답에서 사용자 식별 정보를 추출합니다.
    private func requestAuthIdentity(
        path: String,
        query: String?,
        payload: [String: String]
    ) async throws -> AuthCredentialResult {
        guard let config = SupabaseRuntimeConfig.load() else {
            throw SupabaseAuthError.notConfigured
        }

        let endpoint = SupabaseEndpoint.auth(path: path, query: query)
        let url = endpoint.resolveURL(baseURL: config.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            throw SupabaseAuthError.responseDecodeFailed
        }

        let decoded = try? JSONDecoder().decode(SupabaseAuthResponseDTO.self, from: data)
        guard (200..<300).contains(statusCode) else {
            if statusCode == 400 || statusCode == 401 {
                throw SupabaseAuthError.invalidCredentials
            }
            let description = decoded?.errorDescription ?? decoded?.message ?? decoded?.error ?? "인증에 실패했습니다. (\(statusCode))"
            if description.localizedCaseInsensitiveContains("already") {
                throw SupabaseAuthError.userAlreadyExists
            }
            throw SupabaseAuthError.requestFailed(description)
        }

        guard let result = decoded?.toCredentialResult(
            fallbackEmail: payload["email"],
            now: Date()
        ) else {
            throw SupabaseAuthError.responseDecodeFailed
        }
        return result
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
