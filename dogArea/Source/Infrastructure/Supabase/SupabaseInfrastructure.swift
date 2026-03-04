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
    let code: Int?
    let errorCode: String?
    let message: String?
    let msg: String?
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
        case code
        case errorCode = "error_code"
        case message
        case msg
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
    private let metricTracker: AppMetricTracker

    init(
        session: URLSession = .shared,
        configLoader: @escaping () -> SupabaseRuntimeConfig? = { SupabaseRuntimeConfig.load() },
        authSessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared,
        metricTracker: AppMetricTracker = .shared
    ) {
        self.session = session
        self.configLoader = configLoader
        self.authSessionStore = authSessionStore
        self.metricTracker = metricTracker
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
        let startedAt = Date()
        #if DEBUG
        print("[SupabaseHTTP] -> \(method.rawValue) \(url.absoluteString) body=\(bodyData?.count ?? 0)B")
        #endif

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            #if DEBUG
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("[SupabaseHTTP] xx \(method.rawValue) \(url.absoluteString) elapsed=\(elapsedMs)ms error=\(error.localizedDescription)")
            #endif
            throw error
        }
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            #if DEBUG
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("[SupabaseHTTP] xx \(method.rawValue) \(url.absoluteString) elapsed=\(elapsedMs)ms invalid-response")
            #endif
            throw SupabaseHTTPError.invalidResponse
        }
        guard (200..<300).contains(statusCode) else {
            #if DEBUG
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("[SupabaseHTTP] <- \(method.rawValue) \(url.absoluteString) status=\(statusCode) elapsed=\(elapsedMs)ms response=\(data.count)B")
            #endif
            throw SupabaseHTTPError.unexpectedStatusCode(statusCode)
        }
        #if DEBUG
        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        print("[SupabaseHTTP] <- \(method.rawValue) \(url.absoluteString) status=\(statusCode) elapsed=\(elapsedMs)ms response=\(data.count)B")
        #endif
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
                metricTracker.track(
                    .syncAuthRefreshSucceeded,
                    userKey: refreshed.identity.userId
                )
                return tokenSession.accessToken
            }
            metricTracker.track(
                .syncAuthRefreshFailed,
                userKey: refreshed.identity.userId,
                payload: ["reason": "missing_token_session"]
            )
            authSessionStore.clearTokenSession()
            return nil
        case .retryableFailure:
            metricTracker.track(
                .syncAuthRefreshFailed,
                userKey: currentIdentityUserId(),
                payload: ["reason": "retryable_failure"]
            )
            return nil
        case .terminalFailure:
            metricTracker.track(
                .syncAuthRefreshFailed,
                userKey: currentIdentityUserId(),
                payload: ["reason": "terminal_failure"]
            )
            authSessionStore.clearTokenSession()
            return nil
        }
    }

    /// 현재 저장된 인증 식별자에서 사용자 ID를 조회합니다.
    /// - Returns: 로컬에 사용자 식별자가 있으면 해당 userId, 없으면 `nil`입니다.
    private func currentIdentityUserId() -> String? {
        authSessionStore.currentIdentity()?.userId
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
        let startedAt = Date()
        #if DEBUG
        print("[SupabaseAuth] -> POST refresh-token")
        #endif

        guard let (data, response) = try? await session.data(for: request),
              let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            #if DEBUG
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("[SupabaseAuth] xx refresh-token elapsed=\(elapsedMs)ms request-failed")
            #endif
            return .retryableFailure
        }

        guard (200..<300).contains(statusCode) else {
            #if DEBUG
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("[SupabaseAuth] <- refresh-token status=\(statusCode) elapsed=\(elapsedMs)ms")
            #endif
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
            #if DEBUG
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("[SupabaseAuth] xx refresh-token decode-failed elapsed=\(elapsedMs)ms")
            #endif
            return .terminalFailure
        }
        #if DEBUG
        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        print("[SupabaseAuth] <- refresh-token status=200 elapsed=\(elapsedMs)ms")
        #endif
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

struct WalkLivePresenceDTO: Identifiable, Equatable {
    let ownerUserId: String
    let sessionId: String
    let coordinate: CLLocationCoordinate2D
    let speedMetersPerSecond: Double?
    let sequence: Int
    let idempotencyKey: String
    let updatedAtEpoch: TimeInterval
    let expiresAtEpoch: TimeInterval
    let privacyMode: String?
    let writeApplied: Bool?

    var id: String { ownerUserId }

    /// 두 라이브 프레즌스 DTO가 동일 사용자 상태를 의미하는지 비교합니다.
    /// - Parameters:
    ///   - lhs: 좌측 비교 대상 DTO입니다.
    ///   - rhs: 우측 비교 대상 DTO입니다.
    /// - Returns: 핵심 식별자/좌표/상태 필드가 모두 같으면 `true`를 반환합니다.
    static func == (lhs: WalkLivePresenceDTO, rhs: WalkLivePresenceDTO) -> Bool {
        lhs.ownerUserId == rhs.ownerUserId &&
        lhs.sessionId == rhs.sessionId &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.speedMetersPerSecond == rhs.speedMetersPerSecond &&
        lhs.sequence == rhs.sequence &&
        lhs.idempotencyKey == rhs.idempotencyKey &&
        lhs.updatedAtEpoch == rhs.updatedAtEpoch &&
        lhs.expiresAtEpoch == rhs.expiresAtEpoch &&
        lhs.privacyMode == rhs.privacyMode &&
        lhs.writeApplied == rhs.writeApplied
    }
}

protocol NearbyPresenceServiceProtocol {
    func setVisibility(userId: String, enabled: Bool) async throws
    func upsertPresence(userId: String, latitude: Double, longitude: Double) async throws
    func getHotspots(userId: String?, centerLatitude: Double, centerLongitude: Double, radiusKm: Double) async throws -> [NearbyHotspotDTO]
    /// 실시간 위치 표시용 원시 presence 레코드를 멱등 업서트합니다.
    /// - Parameters:
    ///   - userId: presence 소유 사용자 UUID 문자열입니다.
    ///   - sessionId: 현재 산책 세션 UUID 문자열입니다. `nil`이면 서버가 사용자 ID를 대체 세션으로 사용합니다.
    ///   - latitude: 업서트할 위도 값입니다.
    ///   - longitude: 업서트할 경도 값입니다.
    ///   - speedMetersPerSecond: 현재 이동 속도(m/s)입니다.
    ///   - sequence: last-write-wins 비교용 단조 증가 시퀀스입니다.
    ///   - idempotencyKey: 재전송 중복 제거를 위한 멱등 키입니다.
    /// - Returns: 서버에 반영된 최신 라이브 프레즌스 행입니다. visibility OFF 등으로 저장이 생략되면 `nil`입니다.
    func upsertLivePresence(
        userId: String,
        sessionId: String?,
        latitude: Double,
        longitude: Double,
        speedMetersPerSecond: Double?,
        sequence: Int?,
        idempotencyKey: String?
    ) async throws -> WalkLivePresenceDTO?
    /// 지정한 viewport 범위의 실시간 프레즌스 목록을 조회합니다.
    /// - Parameters:
    ///   - minLatitude: 조회 최소 위도 경계입니다.
    ///   - maxLatitude: 조회 최대 위도 경계입니다.
    ///   - minLongitude: 조회 최소 경도 경계입니다.
    ///   - maxLongitude: 조회 최대 경도 경계입니다.
    ///   - maxRows: 최대 반환 row 수입니다.
    ///   - privacyMode: 조회 프라이버시 모드(`public`/`private`/`all`)입니다.
    /// - Returns: viewport 범위와 프라이버시 필터가 적용된 실시간 프레즌스 목록입니다.
    func getLivePresence(
        minLatitude: Double,
        maxLatitude: Double,
        minLongitude: Double,
        maxLongitude: Double,
        maxRows: Int,
        privacyMode: String
    ) async throws -> [WalkLivePresenceDTO]
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

struct QuestRivalWidgetSummaryDTO: Equatable {
    let questInstanceId: String?
    let questTitle: String
    let questProgressValue: Double
    let questTargetValue: Double
    let questProgressRatio: Double
    let questClaimable: Bool
    let questRewardPoint: Int
    let rivalRank: Int?
    let rivalRankDelta: Int
    let rivalLeague: String
    let refreshedAt: TimeInterval
    let hasData: Bool
}

struct QuestRewardClaimDTO: Equatable {
    let questInstanceId: String
    let claimStatus: String
    let alreadyClaimed: Bool
    let rewardPoints: Int
    let claimedAt: TimeInterval?
}

protocol QuestRivalWidgetSummaryServiceProtocol {
    /// 위젯용 퀘스트/라이벌 결합 요약 지표를 조회합니다.
    /// - Parameter now: 서버 집계 기준 시각입니다.
    /// - Returns: 퀘스트 진행률, 보상 가능 여부, 라이벌 순위를 포함한 요약 DTO입니다.
    func fetchSummary(now: Date) async throws -> QuestRivalWidgetSummaryDTO
}

protocol QuestRivalWidgetSnapshotSyncing {
    /// 서버 요약을 조회해 퀘스트/라이벌 위젯 공유 스냅샷을 갱신합니다.
    /// - Parameters:
    ///   - force: `true`면 TTL을 무시하고 즉시 갱신합니다.
    ///   - now: TTL/상태 계산 기준 시각입니다.
    func sync(force: Bool, now: Date) async
}

protocol QuestRewardClaimServiceProtocol {
    /// 퀘스트 보상 수령을 서버 RPC로 요청합니다.
    /// - Parameters:
    ///   - questInstanceId: 보상을 수령할 퀘스트 인스턴스 식별자입니다.
    ///   - requestId: 멱등 처리를 위한 요청 식별자입니다.
    ///   - now: 서버 처리 기준 시각입니다.
    /// - Returns: 수령 상태/중복 여부/보상 포인트를 포함한 응답 DTO입니다.
    func claimReward(questInstanceId: String, requestId: String, now: Date) async throws -> QuestRewardClaimDTO
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

struct HotspotWidgetSummaryDTO: Equatable {
    let signalLevel: HotspotWidgetSignalLevel
    let highCellCount: Int
    let mediumCellCount: Int
    let lowCellCount: Int
    let delayMinutes: Int
    let privacyMode: String
    let suppressionReason: String?
    let guideCopy: String
    let hasData: Bool
    let isCached: Bool
    let refreshedAt: TimeInterval
}

protocol HotspotWidgetSummaryServiceProtocol {
    /// 위젯용 익명 핫스팟 요약 지표를 조회합니다.
    /// - Parameters:
    ///   - radiusKm: 사용자 주변 집계 반경(km)입니다.
    ///   - now: 서버 집계 기준 시각입니다.
    /// - Returns: 활성도 단계/억제 사유/안내 문구를 포함한 요약 DTO입니다.
    func fetchSummary(radiusKm: Double, now: Date) async throws -> HotspotWidgetSummaryDTO
}

protocol HotspotWidgetSnapshotSyncing {
    /// 서버 요약을 조회해 핫스팟 위젯 공유 스냅샷을 갱신합니다.
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
    private static let functionUnavailableUntilKey = "caricature.edge.unavailable.until.v1"
    private static let functionUnavailableCooldownSeconds: TimeInterval = 10 * 60

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
        case functionUnavailable(cooldownMinutes: Int)
        case invalidResponse
        case requestFailed(code: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Supabase 설정이 누락되어 캐리커처 요청을 보낼 수 없습니다."
            case .functionUnavailable(let cooldownMinutes):
                return "캐리커처 서버 기능이 아직 배포되지 않았습니다. 약 \(cooldownMinutes)분 후 다시 시도해주세요."
            case .invalidResponse:
                return "캐리커처 응답을 해석할 수 없습니다."
            case .requestFailed(_, let message):
                return message
            }
        }
    }

    private let client: SupabaseHTTPClient
    private let availabilityStore: UserDefaults

    init(
        client: SupabaseHTTPClient = .live,
        availabilityStore: UserDefaults = .standard
    ) {
        self.client = client
        self.availabilityStore = availabilityStore
    }

    /// 캐리커처 Edge Function 요청을 전송하고 결과를 반환합니다.
    /// - Parameters:
    ///   - petId: 생성 대상 반려견 UUID 문자열입니다.
    ///   - userId: 요청 사용자 UUID 문자열입니다.
    ///   - sourceImagePath: Storage 버킷 기준 소스 이미지 경로입니다.
    ///   - sourceImageURL: 외부/공개 소스 이미지 URL입니다.
    ///   - style: 요청할 캐리커처 스타일 키입니다.
    ///   - providerHint: 우선 시도할 공급자 힌트(`auto/gemini/openai`)입니다.
    ///   - requestId: 멱등/관측용 요청 식별자(UUID)입니다.
    /// - Returns: 서버가 반환한 작업/결과 메타데이터입니다.
    func requestCaricature(
        petId: String,
        userId: String?,
        sourceImagePath: String? = nil,
        sourceImageURL: String? = nil,
        style: String = "cute_cartoon",
        providerHint: String = "auto",
        requestId: String
    ) async throws -> ResponseDTO {
        guard isFunctionTemporarilyUnavailable() == false else {
            throw RequestError.functionUnavailable(
                cooldownMinutes: Int(Self.functionUnavailableCooldownSeconds / 60)
            )
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

        do {
            let data = try await client.request(
                .function(name: "caricature"),
                method: .post,
                body: payload
            )
            guard let decoded = try? JSONDecoder().decode(ResponseDTO.self, from: data) else {
                throw RequestError.invalidResponse
            }
            clearFunctionUnavailableMarker()
            return decoded
        } catch let error as SupabaseHTTPError {
            switch error {
            case .notConfigured:
                throw RequestError.notConfigured
            case .unexpectedStatusCode(let code):
                if code == 404 {
                    markFunctionTemporarilyUnavailable()
                    throw RequestError.functionUnavailable(
                        cooldownMinutes: Int(Self.functionUnavailableCooldownSeconds / 60)
                    )
                }
                throw RequestError.requestFailed(code: code, message: "캐리커처 생성 실패(\(code)).")
            default:
                throw RequestError.invalidResponse
            }
        }
    }

    /// 최근 404로 인해 캐리커처 함수가 일시 비활성 상태인지 확인합니다.
    /// - Parameter now: 쿨다운 만료 판정 기준 시각입니다.
    /// - Returns: 현재 시각 기준 쿨다운이 남아 있으면 `true`를 반환합니다.
    private func isFunctionTemporarilyUnavailable(now: Date = Date()) -> Bool {
        let until = availabilityStore.double(forKey: Self.functionUnavailableUntilKey)
        return until > now.timeIntervalSince1970
    }

    /// 캐리커처 함수 404 감지 시 재시도 폭주를 막기 위해 쿨다운을 기록합니다.
    /// - Parameter now: 쿨다운 만료시각 계산 기준 시각입니다.
    private func markFunctionTemporarilyUnavailable(now: Date = Date()) {
        let until = now.timeIntervalSince1970 + Self.functionUnavailableCooldownSeconds
        availabilityStore.set(until, forKey: Self.functionUnavailableUntilKey)
    }

    /// 캐리커처 요청이 성공하면 함수 비가용 쿨다운 마커를 제거합니다.
    /// - Returns: 없음.
    private func clearFunctionUnavailableMarker() {
        availabilityStore.removeObject(forKey: Self.functionUnavailableUntilKey)
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

    private enum SyncWalkFunctionRoute {
        static let primary = "sync-walk"
        static let legacy = "sync_walk"
    }

    private static let syncWalkFunctionUnavailableUntilKey = "sync.walk.function.unavailable.until.v1"
    private static let syncWalkFunctionUnavailableCooldownSeconds: TimeInterval = 10 * 60

    private let client: SupabaseHTTPClient
    private let availabilityStore: UserDefaults

    init(
        client: SupabaseHTTPClient = .live,
        availabilityStore: UserDefaults = .standard
    ) {
        self.client = client
        self.availabilityStore = availabilityStore
    }

    func send(item: SyncOutboxItem) async -> SyncOutboxSendResult {
        guard AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) else {
            #if DEBUG
            print("[SyncTransport] blocked: cloudSync unavailable stage=\(item.stage.rawValue) session=\(item.walkSessionId)")
            #endif
            return .retryable(.unauthorized)
        }
        guard isSyncWalkFunctionTemporarilyUnavailable() == false else {
            #if DEBUG
            print("[SyncTransport] blocked: sync-walk cooldown stage=\(item.stage.rawValue) session=\(item.walkSessionId)")
            #endif
            return .permanent(.notConfigured)
        }

        let body: [String: Any] = [
            "action": "sync_walk_stage",
            "walk_session_id": item.walkSessionId,
            "stage": item.stage.rawValue,
            "idempotency_key": item.idempotencyKey,
            "payload": item.payload
        ]

        do {
            let data = try await requestSyncWalkFunction(
                bodyData: try JSONSerialization.data(withJSONObject: body)
            )
            clearSyncWalkFunctionUnavailableMarker()
            persistSeasonCatchupBuffSnapshotIfNeeded(item: item, data: data)
            #if DEBUG
            print("[SyncTransport] success stage=\(item.stage.rawValue) session=\(item.walkSessionId)")
            #endif
            return .success
        } catch let error as SupabaseHTTPError {
            #if DEBUG
            print("[SyncTransport] http-error stage=\(item.stage.rawValue) session=\(item.walkSessionId) error=\(error.localizedDescription)")
            #endif
            switch error {
            case .notConfigured:
                markSyncWalkFunctionTemporarilyUnavailable()
                return .permanent(.notConfigured)
            case .unexpectedStatusCode(let statusCode):
                switch statusCode {
                case 401, 403:
                    return .retryable(.tokenExpired)
                case 409:
                    return .success
                case 429, 500..<600:
                    return .retryable(.serverError)
                case 404:
                    markSyncWalkFunctionTemporarilyUnavailable()
                    return .permanent(.notConfigured)
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
            #if DEBUG
            print("[SyncTransport] url-error stage=\(item.stage.rawValue) session=\(item.walkSessionId) error=\(error.localizedDescription)")
            #endif
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .retryable(.offline)
            case .userAuthenticationRequired:
                return .retryable(.tokenExpired)
            default:
                return .retryable(.unknown)
            }
        } catch {
            #if DEBUG
            print("[SyncTransport] unknown-error stage=\(item.stage.rawValue) session=\(item.walkSessionId) error=\(error.localizedDescription)")
            #endif
            return .retryable(.unknown)
        }
    }

    func fetchBackfillValidationSummary(sessionIds: [String]) async -> SyncBackfillValidationSummary? {
        guard AppFeatureGate.isAllowed(.cloudSync, session: AppFeatureGate.currentSession()) else {
            #if DEBUG
            print("[SyncTransport] validate-backfill blocked: cloudSync unavailable")
            #endif
            return nil
        }
        guard isSyncWalkFunctionTemporarilyUnavailable() == false else {
            #if DEBUG
            print("[SyncTransport] validate-backfill blocked: sync-walk cooldown")
            #endif
            return nil
        }
        let normalized = sessionIds
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.isEmpty == false }
        guard normalized.isEmpty == false else {
            return SyncBackfillValidationSummary(sessionCount: 0, pointCount: 0, totalAreaM2: 0, totalDurationSec: 0)
        }
        #if DEBUG
        print("[SyncTransport] validate-backfill request sessions=\(normalized.count)")
        #endif

        let body: [String: Any] = [
            "action": "validate_backfill",
            "session_ids": normalized
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return nil
        }
        let data: Data
        do {
            data = try await requestSyncWalkFunction(bodyData: bodyData)
            clearSyncWalkFunctionUnavailableMarker()
        } catch let error as SupabaseHTTPError {
            #if DEBUG
            print("[SyncTransport] validate-backfill http-error=\(error.localizedDescription)")
            #endif
            if case .notConfigured = error {
                markSyncWalkFunctionTemporarilyUnavailable()
            } else if case .unexpectedStatusCode(404) = error {
                markSyncWalkFunctionTemporarilyUnavailable()
            }
            return nil
        } catch {
            #if DEBUG
            print("[SyncTransport] validate-backfill unknown-error=\(error.localizedDescription)")
            #endif
            return nil
        }

        guard let decoded = try? JSONDecoder().decode(BackfillSummaryResponseDTO.self, from: data),
              let summary = decoded.summary else {
            #if DEBUG
            print("[SyncTransport] validate-backfill decode-failed")
            #endif
            return nil
        }
        #if DEBUG
        print(
            "[SyncTransport] validate-backfill success sessions=\(summary.sessionCount) points=\(summary.pointCount)"
        )
        #endif

        return SyncBackfillValidationSummary(
            sessionCount: summary.sessionCount,
            pointCount: summary.pointCount,
            totalAreaM2: summary.totalAreaM2,
            totalDurationSec: summary.totalDurationSec
        )
    }

    /// `sync-walk` 함수 호출을 수행하고 404 발생 시 legacy 라우트(`sync_walk`)로 한 번 더 시도합니다.
    /// - Parameter bodyData: 함수 요청 본문(JSON) 데이터입니다.
    /// - Returns: 함수 응답 데이터입니다.
    private func requestSyncWalkFunction(bodyData: Data) async throws -> Data {
        do {
            return try await client.request(
                .function(name: SyncWalkFunctionRoute.primary),
                method: .post,
                bodyData: bodyData
            )
        } catch let error as SupabaseHTTPError {
            guard case .unexpectedStatusCode(404) = error else {
                throw error
            }
            return try await client.request(
                .function(name: SyncWalkFunctionRoute.legacy),
                method: .post,
                bodyData: bodyData
            )
        }
    }

    /// `sync-walk` 함수 404 감지 이후 쿨다운 중인지 확인합니다.
    /// - Parameter now: 쿨다운 만료 판정 기준 시각입니다.
    /// - Returns: 쿨다운이 남아 있으면 `true`입니다.
    private func isSyncWalkFunctionTemporarilyUnavailable(now: Date = Date()) -> Bool {
        let until = availabilityStore.double(forKey: Self.syncWalkFunctionUnavailableUntilKey)
        return until > now.timeIntervalSince1970
    }

    /// `sync-walk` 함수 404 발생 시 재시도 폭주를 방지하기 위해 쿨다운 마커를 기록합니다.
    /// - Parameter now: 쿨다운 만료시각 계산 기준 시각입니다.
    private func markSyncWalkFunctionTemporarilyUnavailable(now: Date = Date()) {
        let until = now.timeIntervalSince1970 + Self.syncWalkFunctionUnavailableCooldownSeconds
        availabilityStore.set(until, forKey: Self.syncWalkFunctionUnavailableUntilKey)
    }

    /// `sync-walk` 호출 성공 시 비가용 쿨다운 마커를 제거합니다.
    private func clearSyncWalkFunctionUnavailableMarker() {
        availabilityStore.removeObject(forKey: Self.syncWalkFunctionUnavailableUntilKey)
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
        let privacy_mode: String?
        let suppression_reason: String?
        let delay_minutes: Int?
        let required_min_sample: Int?
    }

    private struct HotspotEnvelope: Decodable {
        let hotspots: [ResponseHotspotDTO]
    }

    private struct ResponseLivePresenceDTO: Decodable {
        let owner_user_id: String
        let session_id: String
        let lat_rounded: Double
        let lng_rounded: Double
        let speed_mps: Double?
        let sequence: Int
        let idempotency_key: String
        let updated_at: String?
        let expires_at: String?
        let privacy_mode: String?
        let write_applied: Bool?
    }

    private struct LivePresenceUpsertEnvelope: Decodable {
        let live_presence: ResponseLivePresenceDTO?
    }

    private struct LivePresenceEnvelope: Decodable {
        let presence: [ResponseLivePresenceDTO]
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

    /// 실시간 위치 표시용 원시 presence 레코드를 멱등 업서트합니다.
    /// - Parameters:
    ///   - userId: presence 소유 사용자 UUID 문자열입니다.
    ///   - sessionId: 현재 산책 세션 UUID 문자열입니다. `nil`이면 서버 기본값을 사용합니다.
    ///   - latitude: 업서트할 위도 값입니다.
    ///   - longitude: 업서트할 경도 값입니다.
    ///   - speedMetersPerSecond: 이동 속도(m/s)입니다.
    ///   - sequence: last-write-wins 비교용 시퀀스입니다.
    ///   - idempotencyKey: 재전송 중복 제거용 멱등 키입니다.
    /// - Returns: 서버가 반영한 최신 라이브 presence 행입니다. 공유 OFF로 생략되면 `nil`입니다.
    func upsertLivePresence(
        userId: String,
        sessionId: String?,
        latitude: Double,
        longitude: Double,
        speedMetersPerSecond: Double?,
        sequence: Int?,
        idempotencyKey: String?
    ) async throws -> WalkLivePresenceDTO? {
        var payload: [String: Any] = [
            "action": "upsert_live_presence",
            "userId": userId,
            "lat": latitude,
            "lng": longitude
        ]
        if let sessionId, sessionId.isEmpty == false {
            payload["sessionId"] = sessionId
        }
        if let speedMetersPerSecond {
            payload["speedMps"] = speedMetersPerSecond
        }
        if let sequence {
            payload["sequence"] = sequence
        }
        if let idempotencyKey, idempotencyKey.isEmpty == false {
            payload["idempotencyKey"] = idempotencyKey
        }

        let data = try await client.request(
            .function(name: "nearby-presence"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )

        let decoded = try JSONDecoder().decode(LivePresenceUpsertEnvelope.self, from: data)
        guard let row = decoded.live_presence else {
            return nil
        }
        return Self.makeLivePresenceDTO(from: row)
    }

    /// 지정한 viewport 범위의 실시간 presence 목록을 조회합니다.
    /// - Parameters:
    ///   - minLatitude: 조회 최소 위도 경계입니다.
    ///   - maxLatitude: 조회 최대 위도 경계입니다.
    ///   - minLongitude: 조회 최소 경도 경계입니다.
    ///   - maxLongitude: 조회 최대 경도 경계입니다.
    ///   - maxRows: 조회 최대 반환 row 수입니다.
    ///   - privacyMode: 조회 프라이버시 모드(`public`/`private`/`all`)입니다.
    /// - Returns: 만료/프라이버시 필터가 적용된 실시간 presence 목록입니다.
    func getLivePresence(
        minLatitude: Double,
        maxLatitude: Double,
        minLongitude: Double,
        maxLongitude: Double,
        maxRows: Int = 200,
        privacyMode: String = "public"
    ) async throws -> [WalkLivePresenceDTO] {
        let payload: [String: Any] = [
            "action": "get_live_presence",
            "minLat": minLatitude,
            "maxLat": maxLatitude,
            "minLng": minLongitude,
            "maxLng": maxLongitude,
            "maxRows": maxRows,
            "privacyMode": privacyMode
        ]

        let data = try await client.request(
            .function(name: "nearby-presence"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )

        let decoded = try JSONDecoder().decode(LivePresenceEnvelope.self, from: data)
        return decoded.presence.map(Self.makeLivePresenceDTO)
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
                centerCoordinate: CLLocationCoordinate2D(latitude: $0.center_lat, longitude: $0.center_lng),
                privacyMode: $0.privacy_mode,
                suppressionReason: $0.suppression_reason,
                delayMinutes: $0.delay_minutes,
                requiredMinSample: $0.required_min_sample
            )
        }
    }

    /// Edge Function 응답 행을 앱 도메인용 라이브 프레즌스 DTO로 변환합니다.
    /// - Parameter row: `rpc_get_walk_live_presence` 또는 `rpc_upsert_walk_live_presence` 응답 행입니다.
    /// - Returns: UI/도메인 계층에서 바로 사용할 수 있는 라이브 프레즌스 DTO입니다.
    private static func makeLivePresenceDTO(from row: ResponseLivePresenceDTO) -> WalkLivePresenceDTO {
        WalkLivePresenceDTO(
            ownerUserId: row.owner_user_id,
            sessionId: row.session_id,
            coordinate: CLLocationCoordinate2D(latitude: row.lat_rounded, longitude: row.lng_rounded),
            speedMetersPerSecond: row.speed_mps,
            sequence: row.sequence,
            idempotencyKey: row.idempotency_key,
            updatedAtEpoch: SupabaseISO8601.parseEpoch(row.updated_at) ?? 0,
            expiresAtEpoch: SupabaseISO8601.parseEpoch(row.expires_at) ?? 0,
            privacyMode: row.privacy_mode,
            writeApplied: row.write_applied
        )
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

struct QuestRewardClaimService: QuestRewardClaimServiceProtocol {
    private struct ClaimEnvelopeDTO: Decodable {
        let claim: ResponseRowDTO?
    }

    private struct ResponseRowDTO: Decodable {
        let questInstanceId: String?
        let claimStatus: String?
        let alreadyClaimed: Bool?
        let rewardPoints: Int?
        let claimedAt: String?

        enum CodingKeys: String, CodingKey {
            case questInstanceId = "quest_instance_id"
            case claimStatus = "claim_status"
            case alreadyClaimed = "already_claimed"
            case rewardPoints = "reward_points"
            case claimedAt = "claimed_at"
        }
    }

    private let client: SupabaseHTTPClient

    /// 퀘스트 보상 수령 서비스 인스턴스를 생성합니다.
    /// - Parameter client: Supabase 요청을 수행하는 HTTP 클라이언트입니다.
    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    /// 퀘스트 보상 수령을 서버 함수로 요청합니다.
    /// - Parameters:
    ///   - questInstanceId: 보상을 수령할 퀘스트 인스턴스 식별자입니다.
    ///   - requestId: 멱등 처리를 위한 요청 식별자입니다.
    ///   - now: 서버 처리 기준 시각입니다.
    /// - Returns: 수령 상태/중복 여부/보상 포인트를 포함한 응답 DTO입니다.
    func claimReward(questInstanceId: String, requestId: String, now: Date) async throws -> QuestRewardClaimDTO {
        guard let canonicalQuestId = questInstanceId.canonicalUUIDString else {
            throw SupabaseHTTPError.invalidBody
        }
        let normalizedRequestId = requestId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? UUID().uuidString.lowercased()
            : requestId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let payload: [String: Any] = [
            "action": "claim_reward",
            "target_instance_id": canonicalQuestId,
            "request_id": normalizedRequestId,
            "now_ts": ISO8601DateFormatter().string(from: now)
        ]
        let data = try await client.request(
            .function(name: "quest-engine"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )
        let envelope = try JSONDecoder().decode(ClaimEnvelopeDTO.self, from: data)
        guard let claim = envelope.claim else {
            throw SupabaseHTTPError.invalidResponse
        }
        return QuestRewardClaimDTO(
            questInstanceId: claim.questInstanceId ?? canonicalQuestId,
            claimStatus: claim.claimStatus ?? "unknown",
            alreadyClaimed: claim.alreadyClaimed ?? false,
            rewardPoints: max(0, claim.rewardPoints ?? 0),
            claimedAt: SupabaseISO8601.parseEpoch(claim.claimedAt)
        )
    }
}

struct QuestRivalWidgetSummaryService: QuestRivalWidgetSummaryServiceProtocol {
    private struct ResponseDTO: Decodable {
        let questInstanceId: String?
        let questTitle: String?
        let questProgressValue: Double?
        let questTargetValue: Double?
        let questClaimable: Bool?
        let questRewardPoint: Int?
        let rivalRank: Int?
        let rivalLeague: String?
        let refreshedAt: String?
        let hasData: Bool?

        enum CodingKeys: String, CodingKey {
            case questInstanceId = "quest_instance_id"
            case questTitle = "quest_title"
            case questProgressValue = "quest_progress_value"
            case questTargetValue = "quest_target_value"
            case questClaimable = "quest_claimable"
            case questRewardPoint = "quest_reward_point"
            case rivalRank = "rival_rank"
            case rivalLeague = "rival_league"
            case refreshedAt = "refreshed_at"
            case hasData = "has_data"
        }
    }

    private struct QuestFallbackRowDTO: Decodable {
        let id: String?
        let titleSnapshot: String?
        let targetValueSnapshot: Double?
        let progressValue: Double?
        let status: String?
        let rewardPointsSnapshot: Int?
        let claimedAt: String?
        let expiresAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case titleSnapshot = "title_snapshot"
            case targetValueSnapshot = "target_value_snapshot"
            case progressValue = "progress_value"
            case status
            case rewardPointsSnapshot = "reward_points_snapshot"
            case claimedAt = "claimed_at"
            case expiresAt = "expires_at"
        }
    }

    private struct RivalFallbackRowDTO: Decodable {
        let rankPosition: Int?
        let effectiveLeague: String?
        let isMe: Bool?

        enum CodingKeys: String, CodingKey {
            case rankPosition = "rank_position"
            case effectiveLeague = "effective_league"
            case isMe = "is_me"
        }
    }

    private struct QuestFallbackSummary {
        let instanceId: String?
        let title: String
        let progressValue: Double
        let targetValue: Double
        let claimable: Bool
        let rewardPoint: Int
    }

    private struct RivalFallbackSummary {
        let rank: Int?
        let league: String
    }

    private let client: SupabaseHTTPClient

    /// 퀘스트/라이벌 위젯 요약 서비스 인스턴스를 생성합니다.
    /// - Parameter client: Supabase 요청을 수행하는 HTTP 클라이언트입니다.
    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    /// 위젯용 퀘스트/라이벌 결합 요약 지표를 조회합니다.
    /// - Parameter now: 서버 집계 기준 시각입니다.
    /// - Returns: 퀘스트 진행률, 보상 가능 여부, 라이벌 순위를 포함한 요약 DTO입니다.
    func fetchSummary(now: Date) async throws -> QuestRivalWidgetSummaryDTO {
        do {
            return try await fetchFromSummaryRPC(now: now)
        } catch {
            return try await fetchFromFallback(now: now)
        }
    }

    /// 전용 요약 RPC 응답을 조회해 위젯 DTO로 변환합니다.
    /// - Parameter now: 서버 집계 기준 시각입니다.
    /// - Returns: 서버 결합 집계 응답을 정규화한 위젯 요약 DTO입니다.
    private func fetchFromSummaryRPC(now: Date) async throws -> QuestRivalWidgetSummaryDTO {
        let payload: [String: Any] = [
            "now_ts": ISO8601DateFormatter().string(from: now)
        ]
        let data = try await client.request(
            .rest(path: "rpc/rpc_get_widget_quest_rival_summary"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )
        let decoded = try decodeSummaryResponse(data: data)
        let questTarget = max(1.0, decoded.questTargetValue ?? 1.0)
        let questProgress = max(0.0, decoded.questProgressValue ?? 0.0)
        let questRatio = min(1.0, max(0.0, questProgress / questTarget))
        let questTitle = (decoded.questTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = questTitle.isEmpty ? "오늘의 퀘스트를 준비 중입니다." : questTitle
        let refreshedAt = SupabaseISO8601.parseEpoch(decoded.refreshedAt) ?? now.timeIntervalSince1970
        return QuestRivalWidgetSummaryDTO(
            questInstanceId: decoded.questInstanceId?.canonicalUUIDString,
            questTitle: resolvedTitle,
            questProgressValue: questProgress,
            questTargetValue: questTarget,
            questProgressRatio: questRatio,
            questClaimable: decoded.questClaimable ?? false,
            questRewardPoint: max(0, decoded.questRewardPoint ?? 0),
            rivalRank: decoded.rivalRank,
            rivalRankDelta: 0,
            rivalLeague: decoded.rivalLeague ?? "onboarding",
            refreshedAt: refreshedAt,
            hasData: decoded.hasData
                ?? (decoded.questInstanceId != nil || decoded.rivalRank != nil)
        )
    }

    /// 요약 RPC 실패 시 기존 테이블/RPC를 조합해 fallback 요약을 생성합니다.
    /// - Parameter now: 서버 집계 기준 시각입니다.
    /// - Returns: 퀘스트/라이벌 fallback 조합 결과 DTO입니다.
    private func fetchFromFallback(now: Date) async throws -> QuestRivalWidgetSummaryDTO {
        async let questSummary = fetchQuestFallback(now: now)
        async let rivalSummary = fetchRivalFallback(now: now)
        let quest = try await questSummary
        let rival = try await rivalSummary

        let questTarget = max(1.0, quest.targetValue)
        let questProgress = max(0.0, quest.progressValue)
        let questRatio = min(1.0, max(0.0, questProgress / questTarget))
        let hasData = quest.instanceId != nil || rival.rank != nil

        return QuestRivalWidgetSummaryDTO(
            questInstanceId: quest.instanceId,
            questTitle: quest.title,
            questProgressValue: questProgress,
            questTargetValue: questTarget,
            questProgressRatio: questRatio,
            questClaimable: quest.claimable,
            questRewardPoint: quest.rewardPoint,
            rivalRank: rival.rank,
            rivalRankDelta: 0,
            rivalLeague: rival.league,
            refreshedAt: now.timeIntervalSince1970,
            hasData: hasData
        )
    }

    /// RPC 응답이 객체/배열 어느 형태든 단일 요약 객체로 파싱합니다.
    /// - Parameter data: RPC 원시 응답 데이터입니다.
    /// - Returns: 단일 요약 응답 DTO입니다.
    private func decodeSummaryResponse(data: Data) throws -> ResponseDTO {
        let decoder = JSONDecoder()
        if let object = try? decoder.decode(ResponseDTO.self, from: data) {
            return object
        }
        if let rows = try? decoder.decode([ResponseDTO].self, from: data),
           let first = rows.first {
            return first
        }
        throw SupabaseHTTPError.invalidResponse
    }

    /// 퀘스트 인스턴스 목록에서 위젯 표시용 대표 퀘스트를 추출합니다.
    /// - Parameter now: 만료 판정 기준 시각입니다.
    /// - Returns: 위젯 표시용 퀘스트 fallback 요약입니다.
    private func fetchQuestFallback(now: Date) async throws -> QuestFallbackSummary {
        let query = "select=id,title_snapshot,target_value_snapshot,progress_value,status,reward_points_snapshot,claimed_at,expires_at&status=in.(active,completed,claimed)&order=updated_at.desc&limit=30"
        let data = try await client.request(
            .rest(path: "quest_instances", query: query),
            method: .get,
            body: Optional<String>.none
        )
        let rows = try JSONDecoder().decode([QuestFallbackRowDTO].self, from: data)
        let nowEpoch = now.timeIntervalSince1970
        let validRows = rows.filter { row in
            guard let expiresAt = SupabaseISO8601.parseEpoch(row.expiresAt) else { return true }
            return expiresAt >= nowEpoch
        }
        let selected = selectQuestRow(from: validRows) ?? validRows.first
        guard let selected else {
            return QuestFallbackSummary(
                instanceId: nil,
                title: "오늘의 퀘스트를 준비 중입니다.",
                progressValue: 0,
                targetValue: 1,
                claimable: false,
                rewardPoint: 0
            )
        }
        let status = (selected.status ?? "").lowercased()
        let target = max(1.0, selected.targetValueSnapshot ?? 1.0)
        let progress = max(0.0, selected.progressValue ?? 0.0)
        let claimable = status == "completed" && selected.claimedAt == nil
        return QuestFallbackSummary(
            instanceId: selected.id?.canonicalUUIDString,
            title: (selected.titleSnapshot ?? "").isEmpty
                ? "오늘의 퀘스트를 준비 중입니다."
                : (selected.titleSnapshot ?? ""),
            progressValue: progress,
            targetValue: target,
            claimable: claimable,
            rewardPoint: max(0, selected.rewardPointsSnapshot ?? 0)
        )
    }

    /// 퀘스트 행 목록에서 보상 가능 퀘스트를 우선 선택합니다.
    /// - Parameter rows: 서버에서 조회한 퀘스트 인스턴스 행 목록입니다.
    /// - Returns: 위젯 카드에 우선 노출할 퀘스트 행입니다.
    private func selectQuestRow(from rows: [QuestFallbackRowDTO]) -> QuestFallbackRowDTO? {
        if let claimable = rows.first(where: { row in
            ((row.status ?? "").lowercased() == "completed") && row.claimedAt == nil
        }) {
            return claimable
        }
        if let active = rows.first(where: { row in
            (row.status ?? "").lowercased() == "active"
        }) {
            return active
        }
        return rows.first
    }

    /// 라이벌 리더보드에서 현재 사용자의 순위/리그를 fallback 요약으로 추출합니다.
    /// - Parameter now: 집계 기준 시각입니다.
    /// - Returns: 순위와 리그를 담은 fallback 요약입니다.
    private func fetchRivalFallback(now: Date) async throws -> RivalFallbackSummary {
        let payload: [String: Any] = [
            "period_type": RivalLeaderboardPeriod.week.rawValue,
            "top_n": 50,
            "now_ts": ISO8601DateFormatter().string(from: now)
        ]
        let data = try await client.request(
            .rest(path: "rpc/rpc_get_rival_leaderboard"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )
        let rows = try JSONDecoder().decode([RivalFallbackRowDTO].self, from: data)
        if let me = rows.first(where: { $0.isMe == true }) {
            return RivalFallbackSummary(
                rank: me.rankPosition,
                league: me.effectiveLeague ?? "onboarding"
            )
        }
        return RivalFallbackSummary(rank: nil, league: "onboarding")
    }
}

final class DefaultQuestRivalWidgetSnapshotSyncService: QuestRivalWidgetSnapshotSyncing {
    private let summaryService: QuestRivalWidgetSummaryServiceProtocol
    private let snapshotStore: QuestRivalWidgetSnapshotStoring
    private let userSessionStore: UserSessionStoreProtocol
    private let preferenceStore: UserDefaults
    private let syncTTL: TimeInterval
    private let staleGraceInterval: TimeInterval
    private let lastSyncKey = "quest.rival.widget.lastSyncAt.v1"
    private let contextKeyStorageKey = "quest.rival.widget.context.v1"

    /// 퀘스트/라이벌 위젯 스냅샷 동기화 서비스를 생성합니다.
    /// - Parameters:
    ///   - summaryService: 서버 요약 RPC 호출 서비스입니다.
    ///   - snapshotStore: 앱 그룹 기반 위젯 스냅샷 저장소입니다.
    ///   - userSessionStore: 현재 로그인 사용자/반려견 컨텍스트 조회 저장소입니다.
    ///   - preferenceStore: 마지막 동기화 메타데이터를 저장할 기본 설정 저장소입니다.
    ///   - syncTTL: RPC 재조회 최소 간격(초)입니다.
    ///   - staleGraceInterval: 오프라인 캐시를 허용할 최대 유예 시간(초)입니다.
    init(
        summaryService: QuestRivalWidgetSummaryServiceProtocol = QuestRivalWidgetSummaryService(),
        snapshotStore: QuestRivalWidgetSnapshotStoring = DefaultQuestRivalWidgetSnapshotStore.shared,
        userSessionStore: UserSessionStoreProtocol = DefaultUserSessionStore.shared,
        preferenceStore: UserDefaults = .standard,
        syncTTL: TimeInterval = 10 * 60,
        staleGraceInterval: TimeInterval = 3 * 60 * 60
    ) {
        self.summaryService = summaryService
        self.snapshotStore = snapshotStore
        self.userSessionStore = userSessionStore
        self.preferenceStore = preferenceStore
        self.syncTTL = syncTTL
        self.staleGraceInterval = staleGraceInterval
    }

    /// 서버 요약을 조회해 퀘스트/라이벌 위젯 공유 스냅샷을 갱신합니다.
    /// - Parameters:
    ///   - force: `true`면 TTL을 무시하고 즉시 갱신합니다.
    ///   - now: TTL/상태 계산 기준 시각입니다.
    func sync(force: Bool, now: Date) async {
        let contextKey = resolveContextKey()
        guard shouldSync(force: force, now: now, contextKey: contextKey) else { return }

        guard let user = userSessionStore.currentUserInfo(),
              user.id.isEmpty == false else {
            saveGuestSnapshot(now: now)
            return
        }

        do {
            let summary = try await summaryService.fetchSummary(now: now)
            saveMemberSnapshot(summary: summary, contextKey: contextKey, now: now)
        } catch {
            saveFailureSnapshot(contextKey: contextKey, now: now)
        }
    }

    /// TTL/컨텍스트 변화를 기준으로 이번 동기화를 수행할지 판단합니다.
    /// - Parameters:
    ///   - force: `true`면 즉시 동기화합니다.
    ///   - now: 판단 기준 시각입니다.
    ///   - contextKey: 현재 로그인 사용자/반려견 컨텍스트 키입니다.
    /// - Returns: 동기화가 필요하면 `true`, 스킵 가능하면 `false`입니다.
    private func shouldSync(force: Bool, now: Date, contextKey: String) -> Bool {
        if force { return true }
        let snapshot = snapshotStore.load()
        if snapshot.contextKey != contextKey {
            return true
        }
        let age = now.timeIntervalSince1970 - snapshot.updatedAt
        return age >= syncTTL
    }

    /// 현재 사용자/선택 반려견 조합으로 컨텍스트 식별 키를 생성합니다.
    /// - Returns: 다계정/다견 전환 감지를 위한 컨텍스트 키 문자열입니다.
    private func resolveContextKey() -> String {
        guard let user = userSessionStore.currentUserInfo(),
              user.id.isEmpty == false else {
            return "guest"
        }
        let selectedPet = userSessionStore.selectedPet(from: user)
        let petId = selectedPet?.petId.lowercased() ?? "none"
        return "\(user.id.lowercased())|\(petId)"
    }

    /// 비회원 상태 스냅샷을 저장합니다.
    /// - Parameter now: 저장 시각입니다.
    private func saveGuestSnapshot(now: Date) {
        save(
            QuestRivalWidgetSnapshot(
                status: .guestLocked,
                message: "로그인 후 퀘스트 진행률과 라이벌 순위를 위젯에서 확인할 수 있어요.",
                summary: nil,
                contextKey: "guest",
                updatedAt: now.timeIntervalSince1970
            ),
            now: now
        )
    }

    /// 서버 요약 응답을 회원 상태 스냅샷으로 저장합니다.
    /// - Parameters:
    ///   - summary: 서버에서 조회한 최신 퀘스트/라이벌 요약 DTO입니다.
    ///   - contextKey: 사용자/반려견 컨텍스트 키입니다.
    ///   - now: 저장 시각입니다.
    private func saveMemberSnapshot(summary: QuestRivalWidgetSummaryDTO, contextKey: String, now: Date) {
        let status: QuestRivalWidgetSnapshotStatus = summary.hasData ? .memberReady : .emptyData
        let rankDelta = resolveRankDelta(currentRank: summary.rivalRank, contextKey: contextKey)
        let snapshot = QuestRivalWidgetSnapshot(
            status: status,
            message: summary.hasData
                ? "퀘스트 진행률과 라이벌 순위를 최신 기준으로 표시합니다."
                : "표시할 퀘스트/라이벌 데이터가 아직 없습니다.",
            summary: QuestRivalWidgetSummarySnapshot(
                questInstanceId: summary.questInstanceId,
                questTitle: summary.questTitle,
                questProgressValue: summary.questProgressValue,
                questTargetValue: summary.questTargetValue,
                questProgressRatio: summary.questProgressRatio,
                questClaimable: summary.questClaimable,
                questRewardPoint: summary.questRewardPoint,
                rivalRank: summary.rivalRank,
                rivalRankDelta: rankDelta,
                rivalLeague: summary.rivalLeague,
                refreshedAt: summary.refreshedAt
            ),
            contextKey: contextKey,
            updatedAt: now.timeIntervalSince1970
        )
        save(snapshot, now: now)
    }

    /// 서버 조회 실패 시 마지막 성공 스냅샷 기반 상태로 저장합니다.
    /// - Parameters:
    ///   - contextKey: 사용자/반려견 컨텍스트 키입니다.
    ///   - now: 저장 시각입니다.
    private func saveFailureSnapshot(contextKey: String, now: Date) {
        let current = snapshotStore.load()
        guard current.contextKey == contextKey,
              let cachedSummary = current.summary else {
            save(
                QuestRivalWidgetSnapshot(
                    status: .syncDelayed,
                    message: "위젯 요약 동기화가 지연되고 있어요. 앱을 열어 최신화해주세요.",
                    summary: nil,
                    contextKey: contextKey,
                    updatedAt: now.timeIntervalSince1970
                ),
                now: now
            )
            return
        }

        let cacheAge = now.timeIntervalSince1970 - cachedSummary.refreshedAt
        let status: QuestRivalWidgetSnapshotStatus = cacheAge <= staleGraceInterval ? .offlineCached : .syncDelayed
        let message: String = cacheAge <= staleGraceInterval
            ? "오프라인 상태예요. 마지막 성공 스냅샷을 표시 중입니다."
            : "동기화가 지연되고 있어요. 앱을 열어 최신화해주세요."
        save(
            QuestRivalWidgetSnapshot(
                status: status,
                message: message,
                summary: cachedSummary,
                contextKey: contextKey,
                updatedAt: now.timeIntervalSince1970
            ),
            now: now
        )
    }

    /// 현재 랭크와 이전 저장 랭크를 비교해 순위 변화량을 계산합니다.
    /// - Parameters:
    ///   - currentRank: 이번 동기화에서 조회한 현재 랭크입니다.
    ///   - contextKey: 사용자/반려견 컨텍스트 키입니다.
    /// - Returns: 이전 랭크 대비 상승(+)/하락(-) 변화량입니다.
    private func resolveRankDelta(currentRank: Int?, contextKey: String) -> Int {
        let storageKey = "quest.rival.widget.lastRank.v1.\(contextKey)"
        defer {
            if let currentRank {
                preferenceStore.set(currentRank, forKey: storageKey)
            } else {
                preferenceStore.removeObject(forKey: storageKey)
            }
        }
        guard let currentRank else { return 0 }
        guard preferenceStore.object(forKey: storageKey) != nil else { return 0 }
        let previousRank = preferenceStore.integer(forKey: storageKey)
        return previousRank - currentRank
    }

    /// 위젯 스냅샷 저장 후 재로딩을 요청하고 마지막 동기화 시각을 기록합니다.
    /// - Parameters:
    ///   - snapshot: 저장할 퀘스트/라이벌 위젯 스냅샷입니다.
    ///   - now: 마지막 동기화 시각 기록 기준입니다.
    private func save(_ snapshot: QuestRivalWidgetSnapshot, now: Date) {
        snapshotStore.save(snapshot)
        preferenceStore.set(now.timeIntervalSince1970, forKey: lastSyncKey)
        preferenceStore.set(snapshot.contextKey, forKey: contextKeyStorageKey)
        reloadQuestRivalWidgetTimeline()
    }

    /// WidgetKit 타임라인을 즉시 재요청해 최신 스냅샷이 반영되도록 합니다.
    private func reloadQuestRivalWidgetTimeline() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: WalkWidgetBridgeContract.questRivalWidgetKind)
        #endif
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

struct HotspotWidgetSummaryService: HotspotWidgetSummaryServiceProtocol {
    private struct ResponseDTO: Decodable {
        let signalLevel: String?
        let highCells: Int?
        let mediumCells: Int?
        let lowCells: Int?
        let delayMinutes: Int?
        let privacyMode: String?
        let suppressionReason: String?
        let guideCopy: String?
        let hasData: Bool?
        let isCached: Bool?
        let refreshedAt: String?

        enum CodingKeys: String, CodingKey {
            case signalLevel = "signal_level"
            case highCells = "high_cells"
            case mediumCells = "medium_cells"
            case lowCells = "low_cells"
            case delayMinutes = "delay_minutes"
            case privacyMode = "privacy_mode"
            case suppressionReason = "suppression_reason"
            case guideCopy = "guide_copy"
            case hasData = "has_data"
            case isCached = "is_cached"
            case refreshedAt = "refreshed_at"
        }
    }

    private let client: SupabaseHTTPClient

    /// 익명 핫스팟 위젯 요약 서비스 인스턴스를 생성합니다.
    /// - Parameter client: Supabase 요청을 수행하는 HTTP 클라이언트입니다.
    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    /// 위젯용 익명 핫스팟 요약 지표를 조회합니다.
    /// - Parameters:
    ///   - radiusKm: 사용자 주변 집계 반경(km)입니다.
    ///   - now: 서버 집계 기준 시각입니다.
    /// - Returns: 활성도 단계/억제 사유/안내 문구를 포함한 요약 DTO입니다.
    func fetchSummary(radiusKm: Double, now: Date) async throws -> HotspotWidgetSummaryDTO {
        let payload: [String: Any] = [
            "radius_km": min(5.0, max(0.3, radiusKm)),
            "now_ts": ISO8601DateFormatter().string(from: now)
        ]
        let data = try await client.request(
            .rest(path: "rpc/rpc_get_widget_hotspot_summary"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )
        let decoded = try JSONDecoder().decode(ResponseDTO.self, from: data)
        return HotspotWidgetSummaryDTO(
            signalLevel: mapSignalLevel(decoded.signalLevel),
            highCellCount: max(0, decoded.highCells ?? 0),
            mediumCellCount: max(0, decoded.mediumCells ?? 0),
            lowCellCount: max(0, decoded.lowCells ?? 0),
            delayMinutes: max(0, decoded.delayMinutes ?? 0),
            privacyMode: decoded.privacyMode ?? "none",
            suppressionReason: decoded.suppressionReason,
            guideCopy: decoded.guideCopy ?? "개인 좌표 없이 익명 셀 신호만 제공됩니다.",
            hasData: decoded.hasData ?? false,
            isCached: decoded.isCached ?? false,
            refreshedAt: SupabaseISO8601.parseEpoch(decoded.refreshedAt) ?? now.timeIntervalSince1970
        )
    }

    /// 서버 응답의 문자열 값을 위젯 신호 레벨 열거형으로 변환합니다.
    /// - Parameter rawValue: 서버에서 전달한 `signal_level` 원문 값입니다.
    /// - Returns: 지원하지 않는 값은 `.none`으로 정규화한 신호 레벨입니다.
    private func mapSignalLevel(_ rawValue: String?) -> HotspotWidgetSignalLevel {
        guard let rawValue, let value = HotspotWidgetSignalLevel(rawValue: rawValue) else {
            return .none
        }
        return value
    }
}

final class DefaultHotspotWidgetSnapshotSyncService: HotspotWidgetSnapshotSyncing {
    private let summaryService: HotspotWidgetSummaryServiceProtocol
    private let snapshotStore: HotspotWidgetSnapshotStoring
    private let userSessionStore: UserSessionStoreProtocol
    private let preferenceStore: UserDefaults
    private let syncTTL: TimeInterval
    private let staleGraceInterval: TimeInterval
    private let queryRadiusKm: Double

    /// 핫스팟 위젯 스냅샷 동기화 서비스를 생성합니다.
    /// - Parameters:
    ///   - summaryService: 서버 요약 RPC 호출 서비스입니다.
    ///   - snapshotStore: 앱 그룹 기반 핫스팟 스냅샷 저장소입니다.
    ///   - userSessionStore: 현재 로그인 사용자 컨텍스트 조회 저장소입니다.
    ///   - preferenceStore: 마지막 동기화 메타데이터를 저장할 기본 설정 저장소입니다.
    ///   - syncTTL: RPC 재조회 최소 간격(초)입니다.
    ///   - staleGraceInterval: 오프라인 캐시를 허용할 최대 유예 시간(초)입니다.
    ///   - queryRadiusKm: 서버 요약 조회 시 사용할 반경(km)입니다.
    init(
        summaryService: HotspotWidgetSummaryServiceProtocol = HotspotWidgetSummaryService(),
        snapshotStore: HotspotWidgetSnapshotStoring = DefaultHotspotWidgetSnapshotStore.shared,
        userSessionStore: UserSessionStoreProtocol = DefaultUserSessionStore.shared,
        preferenceStore: UserDefaults = .standard,
        syncTTL: TimeInterval = 10 * 60,
        staleGraceInterval: TimeInterval = 3 * 60 * 60,
        queryRadiusKm: Double = 1.2
    ) {
        self.summaryService = summaryService
        self.snapshotStore = snapshotStore
        self.userSessionStore = userSessionStore
        self.preferenceStore = preferenceStore
        self.syncTTL = syncTTL
        self.staleGraceInterval = staleGraceInterval
        self.queryRadiusKm = queryRadiusKm
    }

    /// 서버 요약을 조회해 핫스팟 위젯 공유 스냅샷을 갱신합니다.
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
            let summary = try await summaryService.fetchSummary(radiusKm: queryRadiusKm, now: now)
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
        save(
            HotspotWidgetSnapshot(
                status: .guestLocked,
                message: "로그인 후 주변 익명 핫스팟 트렌드를 위젯에서 확인할 수 있어요.",
                summary: nil,
                updatedAt: now.timeIntervalSince1970
            ),
            now: now
        )
    }

    /// 서버 요약 응답을 회원 상태 스냅샷으로 저장합니다.
    /// - Parameters:
    ///   - summary: 서버에서 조회한 최신 익명 핫스팟 요약 DTO입니다.
    ///   - now: 저장 시각입니다.
    private func saveMemberSnapshot(summary: HotspotWidgetSummaryDTO, now: Date) {
        let status = resolveMemberStatus(summary)
        let message = messageForMemberSummary(summary, status: status)
        let snapshot = HotspotWidgetSnapshot(
            status: status,
            message: message,
            summary: HotspotWidgetSummarySnapshot(
                signalLevel: summary.signalLevel,
                highCellCount: summary.highCellCount,
                mediumCellCount: summary.mediumCellCount,
                lowCellCount: summary.lowCellCount,
                delayMinutes: summary.delayMinutes,
                privacyMode: summary.privacyMode,
                suppressionReason: summary.suppressionReason,
                guideCopy: summary.guideCopy,
                refreshedAt: summary.refreshedAt
            ),
            updatedAt: now.timeIntervalSince1970
        )
        save(snapshot, now: now)
    }

    /// 서버 요약을 위젯 상태 코드로 정규화합니다.
    /// - Parameter summary: 서버에서 조회한 익명 핫스팟 요약 DTO입니다.
    /// - Returns: 위젯 렌더링에 사용할 상태 코드입니다.
    private func resolveMemberStatus(_ summary: HotspotWidgetSummaryDTO) -> HotspotWidgetSnapshotStatus {
        if summary.hasData == false {
            return .emptyData
        }
        if summary.suppressionReason != nil || summary.privacyMode != "full" {
            return .privacyGuarded
        }
        return .memberReady
    }

    /// 회원 요약 상태별 사용자 안내 문구를 생성합니다.
    /// - Parameters:
    ///   - summary: 서버에서 조회한 익명 핫스팟 요약 DTO입니다.
    ///   - status: 위젯 상태 코드입니다.
    /// - Returns: 상태별 안내 메시지 문자열입니다.
    private func messageForMemberSummary(
        _ summary: HotspotWidgetSummaryDTO,
        status: HotspotWidgetSnapshotStatus
    ) -> String {
        switch status {
        case .memberReady:
            return "개인 식별 정보 없이 익명 활성도 단계만 표시합니다."
        case .privacyGuarded:
            switch summary.suppressionReason {
            case "sensitive_mask":
                return "민감 지역은 보호 정책으로 마스킹되어 상세 표시를 제한합니다."
            case "k_anon":
                return "샘플 수가 부족한 지역은 백분위 단계로만 표시됩니다."
            default:
                return "프라이버시 가드가 적용되어 일부 신호가 축약 표시됩니다."
            }
        case .emptyData:
            return "현재 주변 익명 핫스팟 데이터가 충분하지 않아요."
        default:
            return summary.guideCopy
        }
    }

    /// 서버 조회 실패 시 마지막 성공 스냅샷 기반 상태로 저장합니다.
    /// - Parameter now: 저장 시각입니다.
    private func saveFailureSnapshot(now: Date) {
        let current = snapshotStore.load()
        guard let cachedSummary = current.summary else {
            save(
                HotspotWidgetSnapshot(
                    status: .syncDelayed,
                    message: "동기화가 지연되고 있어요. 앱을 열어 최신화해주세요.",
                    summary: nil,
                    updatedAt: now.timeIntervalSince1970
                ),
                now: now
            )
            return
        }

        let cacheAge = now.timeIntervalSince1970 - cachedSummary.refreshedAt
        let status: HotspotWidgetSnapshotStatus = cacheAge <= staleGraceInterval ? .offlineCached : .syncDelayed
        let message: String = cacheAge <= staleGraceInterval
            ? "오프라인 상태예요. 마지막 익명 스냅샷을 표시 중입니다."
            : "동기화가 지연되고 있어요. 앱을 열어 최신화해주세요."
        save(
            HotspotWidgetSnapshot(
                status: status,
                message: message,
                summary: cachedSummary,
                updatedAt: now.timeIntervalSince1970
            ),
            now: now
        )
    }

    /// 위젯 스냅샷 저장 후 재로딩을 요청하고 마지막 동기화 시각을 기록합니다.
    /// - Parameters:
    ///   - snapshot: 저장할 핫스팟 위젯 스냅샷입니다.
    ///   - now: 마지막 동기화 시각 기록 기준입니다.
    private func save(_ snapshot: HotspotWidgetSnapshot, now: Date) {
        snapshotStore.save(snapshot)
        preferenceStore.set(now.timeIntervalSince1970, forKey: "hotspot.widget.lastSyncAt.v1")
        reloadHotspotWidgetTimeline()
    }

    /// WidgetKit 타임라인을 즉시 재요청해 최신 스냅샷이 반영되도록 합니다.
    private func reloadHotspotWidgetTimeline() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: WalkWidgetBridgeContract.hotspotWidgetKind)
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
    case rateLimited(message: String?, errorCode: String?, retryAfterSeconds: Int?)
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
        case .rateLimited(let message, let errorCode, let retryAfterSeconds):
            let retryText: String = {
                guard let retryAfterSeconds, retryAfterSeconds > 0 else { return "" }
                return " 약 \(retryAfterSeconds)초 후 다시 시도해주세요."
            }()
            switch errorCode {
            case "over_email_send_rate_limit":
                return "Supabase 이메일 발송 한도를 초과했습니다.\(retryText) 잠시 후 재시도하거나 SMTP/Rate Limit 설정을 확인해주세요."
            default:
                if let message, message.isEmpty == false {
                    return "요청이 너무 많아 인증이 제한되었습니다: \(message)\(retryText)"
                }
                return "요청이 너무 많아 인증이 제한되었습니다.\(retryText)"
            }
        case .responseDecodeFailed:
            return "인증 응답을 해석하지 못했습니다."
        case .requestFailed(let message):
            return message
        }
    }
}

enum SupabaseAccountDeletionError: LocalizedError {
    case unauthorized
    case requestFailed(statusCode: Int)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "인증이 만료되어 회원탈퇴를 진행할 수 없습니다. 다시 로그인 후 시도해주세요."
        case .requestFailed(let statusCode):
            return "회원탈퇴 요청에 실패했습니다. (\(statusCode))"
        case .unknown:
            return "회원탈퇴 요청에 실패했습니다. 잠시 후 다시 시도해주세요."
        }
    }
}

final class SupabaseAccountDeletionService: AccountDeletionServiceProtocol {
    static let shared = SupabaseAccountDeletionService()

    private let client: SupabaseHTTPClient

    /// Supabase Auth 기반 회원탈퇴 서비스를 초기화합니다.
    /// - Parameter client: Auth API 요청에 사용할 HTTP 클라이언트입니다.
    init(client: SupabaseHTTPClient = .live) {
        self.client = client
    }

    /// 현재 로그인된 사용자의 계정을 삭제합니다.
    func deleteCurrentAccount() async throws {
        do {
            _ = try await client.request(
                .auth(path: "user"),
                method: .delete,
                bodyData: nil
            )
        } catch let httpError as SupabaseHTTPError {
            switch httpError {
            case .unexpectedStatusCode(let code) where code == 401 || code == 403:
                throw SupabaseAccountDeletionError.unauthorized
            case .unexpectedStatusCode(let code):
                throw SupabaseAccountDeletionError.requestFailed(statusCode: code)
            default:
                throw SupabaseAccountDeletionError.unknown
            }
        } catch {
            throw SupabaseAccountDeletionError.unknown
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

        #if DEBUG
        print("[SupabaseAuth] -> \(path) query=\(query ?? "none") email=\(payload["email"] ?? "none")")
        #endif
        let startedAt = Date()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            #if DEBUG
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("[SupabaseAuth] xx \(path) elapsed=\(elapsedMs)ms error=\(error.localizedDescription)")
            #endif
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthError.responseDecodeFailed
        }
        let statusCode = httpResponse.statusCode

        let decoded = try? JSONDecoder().decode(SupabaseAuthResponseDTO.self, from: data)
        let looseErrorPayload = decodeLooseAuthErrorPayload(from: data)
        let responseErrorCode = decoded?.errorCode
            ?? looseErrorPayload.errorCode
            ?? httpResponse.value(forHTTPHeaderField: "x-sb-error-code")
        let responseMessage = decoded?.errorDescription
            ?? decoded?.message
            ?? decoded?.msg
            ?? decoded?.error
            ?? looseErrorPayload.message

        #if DEBUG
        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        let bodyPreview = String(decoding: data.prefix(220), as: UTF8.self)
        print(
            "[SupabaseAuth] <- \(path) status=\(statusCode) elapsed=\(elapsedMs)ms errorCode=\(responseErrorCode ?? "none") body=\(bodyPreview)"
        )
        #endif

        guard (200..<300).contains(statusCode) else {
            let description = responseMessage ?? "인증에 실패했습니다. (\(statusCode))"
            if isDuplicateEmailErrorDescription(description) {
                throw SupabaseAuthError.userAlreadyExists
            }
            if statusCode == 429 {
                throw SupabaseAuthError.rateLimited(
                    message: description,
                    errorCode: responseErrorCode,
                    retryAfterSeconds: retryAfterSeconds(from: httpResponse)
                )
            }
            if statusCode == 400 || statusCode == 401 {
                throw SupabaseAuthError.invalidCredentials
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

    /// Auth 실패 응답 설명이 이메일 중복 상황인지 판별합니다.
    /// - Parameter description: Auth 응답에서 추출한 오류 설명 문자열입니다.
    /// - Returns: 이메일 중복으로 해석되면 `true`, 아니면 `false`입니다.
    private func isDuplicateEmailErrorDescription(_ description: String) -> Bool {
        let lowercased = description.lowercased()
        return lowercased.contains("already")
            || lowercased.contains("duplicate")
            || lowercased.contains("registered")
            || lowercased.contains("exists")
    }

    /// HTTP 응답에서 `Retry-After` 헤더를 초 단위로 해석합니다.
    /// - Parameter response: Supabase Auth 응답 객체입니다.
    /// - Returns: 재시도 대기 시간이 명시된 경우 초 단위 정수, 없으면 `nil`입니다.
    private func retryAfterSeconds(from response: HTTPURLResponse) -> Int? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              raw.isEmpty == false else {
            return nil
        }
        if let seconds = Int(raw), seconds >= 0 {
            return seconds
        }
        return nil
    }

    /// Auth 오류 바디를 느슨하게 파싱해 메시지/에러코드를 추출합니다.
    /// - Parameter data: Auth 응답 원본 바디 데이터입니다.
    /// - Returns: 추출된 오류 메시지와 오류 코드입니다.
    private func decodeLooseAuthErrorPayload(from data: Data) -> (message: String?, errorCode: String?) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, nil)
        }
        let message = (object["error_description"] as? String)
            ?? (object["message"] as? String)
            ?? (object["msg"] as? String)
            ?? (object["error"] as? String)
        let errorCode = object["error_code"] as? String
        return (message, errorCode)
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
