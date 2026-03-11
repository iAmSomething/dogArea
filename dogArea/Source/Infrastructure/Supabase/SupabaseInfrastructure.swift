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

struct SupabaseAuthUserDTO: Decodable {
    let id: String?
    let email: String?
}

struct SupabaseAuthResponseDTO: Decodable {
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

extension SupabaseAuthResponseDTO {
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
    private static let edgeFunctionAnonRetryAllowlist: Set<String> = [
        "feature-control",
        "nearby-presence",
        "upload-profile-image"
    ]

    private enum AccessTokenValidationState {
        case valid
        case invalid
        case inconclusive
    }

    private enum UnauthorizedRetryRecoveryResult {
        case recovered(data: Data, accessToken: String)
        case unrecovered(statusCode: Int, data: Data, accessToken: String?)
    }

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
        let authorization = await resolvedAuthorizationHeader(config: config)
        let authorizationContext: (
            headerValue: String,
            usedAuthenticatedAccessToken: Bool,
            accessToken: String?
        ) = shouldPreferAnonymousAuthorizationForEndpoint(endpoint)
            ? ("Bearer \(config.anonKey)", false, nil)
            : authorization
        request.setValue(authorizationContext.headerValue, forHTTPHeaderField: "Authorization")
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
            var resolvedStatusCode = statusCode
            var resolvedData = data
            var resolvedAccessToken = authorization.accessToken
            var authenticatedStatusCodeForSessionDecision = statusCode

            if let recoveryResult = await retryUnauthorizedRequestWithRefreshedSessionIfNeeded(
                request: request,
                endpoint: endpoint,
                method: method,
                url: url,
                statusCode: statusCode,
                data: data,
                usedAuthenticatedAccessToken: authorizationContext.usedAuthenticatedAccessToken,
                accessToken: authorizationContext.accessToken,
                config: config,
                startedAt: startedAt
            ) {
                switch recoveryResult {
                case .recovered(let recoveredData, _):
                    #if DEBUG
                    let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                    print("[SupabaseHTTP] <- \(method.rawValue) \(url.absoluteString) status=200 elapsed=\(elapsedMs)ms response=\(recoveredData.count)B (refresh-retry)")
                    #endif
                    return recoveredData
                case .unrecovered(let retryStatusCode, let retryData, let refreshedAccessToken):
                    resolvedStatusCode = retryStatusCode
                    resolvedData = retryData
                    resolvedAccessToken = refreshedAccessToken ?? resolvedAccessToken
                    authenticatedStatusCodeForSessionDecision = retryStatusCode
                }
            }

            if shouldRetryWithAnonAuthorization(
                endpoint: endpoint,
                statusCode: resolvedStatusCode,
                usedAuthenticatedAccessToken: authorizationContext.usedAuthenticatedAccessToken
            ) {
                var anonRequest = request
                anonRequest.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
                #if DEBUG
                print("[SupabaseHTTP] retry-anon \(method.rawValue) \(url.absoluteString)")
                #endif
                do {
                    let (retryData, retryResponse) = try await session.data(for: anonRequest)
                    guard let retryStatusCode = (retryResponse as? HTTPURLResponse)?.statusCode else {
                        #if DEBUG
                        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                        print("[SupabaseHTTP] xx retry-anon \(method.rawValue) \(url.absoluteString) elapsed=\(elapsedMs)ms invalid-response")
                        #endif
                        throw SupabaseHTTPError.invalidResponse
                    }
                    if (200..<300).contains(retryStatusCode) {
                        #if DEBUG
                        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                        print("[SupabaseHTTP] <- \(method.rawValue) \(url.absoluteString) status=\(retryStatusCode) elapsed=\(elapsedMs)ms response=\(retryData.count)B (anon-retry)")
                        #endif
                        return retryData
                    }
                    resolvedStatusCode = retryStatusCode
                    resolvedData = retryData
                    #if DEBUG
                    let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                    print("[SupabaseHTTP] <- \(method.rawValue) \(url.absoluteString) status=\(retryStatusCode) elapsed=\(elapsedMs)ms response=\(retryData.count)B (anon-retry-non2xx)")
                    #endif
                } catch {
                    #if DEBUG
                    let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                    print("[SupabaseHTTP] xx retry-anon \(method.rawValue) \(url.absoluteString) elapsed=\(elapsedMs)ms error=\(error.localizedDescription)")
                    #endif
                    throw error
                }
            }

            if await shouldInvalidateTokenSession(
                statusCode: authenticatedStatusCodeForSessionDecision,
                endpoint: endpoint,
                usedAuthenticatedAccessToken: authorizationContext.usedAuthenticatedAccessToken,
                accessToken: resolvedAccessToken,
                config: config
            ) {
                authSessionStore.clearTokenSession()
                #if DEBUG
                print("[SupabaseAuth] invalidate local token session from response status=\(resolvedStatusCode)")
                #endif
            }
            #if DEBUG
            if authenticatedStatusCodeForSessionDecision != resolvedStatusCode {
                print(
                    "[SupabaseAuth] auth-session decision status=\(authenticatedStatusCodeForSessionDecision) final-response status=\(resolvedStatusCode)"
                )
            }
            #endif
            #if DEBUG
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("[SupabaseHTTP] <- \(method.rawValue) \(url.absoluteString) status=\(resolvedStatusCode) elapsed=\(elapsedMs)ms response=\(resolvedData.count)B")
            #endif
            throw SupabaseHTTPError.unexpectedStatusCode(resolvedStatusCode)
        }
        #if DEBUG
        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        print("[SupabaseHTTP] <- \(method.rawValue) \(url.absoluteString) status=\(statusCode) elapsed=\(elapsedMs)ms response=\(data.count)B")
        #endif
        return data
    }

    /// 사용자 토큰 요청이 401/403일 때 refresh token으로 세션을 갱신한 뒤 동일 요청을 1회 재시도합니다.
    /// - Parameters:
    ///   - request: 원본 HTTP 요청입니다.
    ///   - endpoint: 호출 대상 Supabase 엔드포인트입니다.
    ///   - method: HTTP 메서드입니다.
    ///   - url: 호출 대상 URL입니다.
    ///   - statusCode: 최초 응답의 HTTP 상태 코드입니다.
    ///   - data: 최초 응답 바디 데이터입니다.
    ///   - usedAuthenticatedAccessToken: 최초 요청이 사용자 access token을 사용했는지 여부입니다.
    ///   - accessToken: 최초 요청에 사용한 사용자 access token 문자열입니다.
    ///   - config: Supabase 런타임 기본 구성입니다.
    ///   - startedAt: 최초 요청 시작 시각입니다.
    /// - Returns: refresh 재시도 결과가 있으면 성공/실패 결과를 반환하고, 시도 조건이 아니면 `nil`을 반환합니다.
    private func retryUnauthorizedRequestWithRefreshedSessionIfNeeded(
        request: URLRequest,
        endpoint: SupabaseEndpoint,
        method: HTTPMethod,
        url: URL,
        statusCode: Int,
        data: Data,
        usedAuthenticatedAccessToken: Bool,
        accessToken: String?,
        config: SupabaseRuntimeConfig,
        startedAt: Date
    ) async -> UnauthorizedRetryRecoveryResult? {
        guard usedAuthenticatedAccessToken else { return nil }
        guard statusCode == 401 || statusCode == 403 else { return nil }
        if case .auth = endpoint {
            return nil
        }
        guard let currentSession = authSessionStore.currentTokenSession(),
              currentSession.refreshToken.isEmpty == false else {
            return nil
        }

        #if DEBUG
        print("[SupabaseAuth] retry-with-refresh \(method.rawValue) \(url.absoluteString)")
        #endif

        let refreshOutcome = await refreshCredential(config: config, refreshToken: currentSession.refreshToken)
        switch refreshOutcome {
        case .success(let refreshed):
            guard let tokenSession = refreshed.tokenSession else {
                return .unrecovered(
                    statusCode: statusCode,
                    data: data,
                    accessToken: accessToken
                )
            }
            authSessionStore.persistAuthenticatedSession(identity: refreshed.identity, tokenSession: tokenSession)

            var retryRequest = request
            retryRequest.setValue("Bearer \(tokenSession.accessToken)", forHTTPHeaderField: "Authorization")
            do {
                let (retryData, retryResponse) = try await session.data(for: retryRequest)
                guard let retryStatusCode = (retryResponse as? HTTPURLResponse)?.statusCode else {
                    #if DEBUG
                    let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                    print("[SupabaseHTTP] xx refresh-retry \(method.rawValue) \(url.absoluteString) elapsed=\(elapsedMs)ms invalid-response")
                    #endif
                    return .unrecovered(
                        statusCode: statusCode,
                        data: data,
                        accessToken: tokenSession.accessToken
                    )
                }
                if (200..<300).contains(retryStatusCode) {
                    return .recovered(data: retryData, accessToken: tokenSession.accessToken)
                }
                return .unrecovered(
                    statusCode: retryStatusCode,
                    data: retryData,
                    accessToken: tokenSession.accessToken
                )
            } catch {
                #if DEBUG
                let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                print("[SupabaseHTTP] xx refresh-retry \(method.rawValue) \(url.absoluteString) elapsed=\(elapsedMs)ms error=\(error.localizedDescription)")
                #endif
                return .unrecovered(
                    statusCode: statusCode,
                    data: data,
                    accessToken: tokenSession.accessToken
                )
            }
        case .retryableFailure:
            return .unrecovered(
                statusCode: statusCode,
                data: data,
                accessToken: accessToken
            )
        case .terminalFailure:
            authSessionStore.clearTokenSession()
            return .unrecovered(
                statusCode: statusCode,
                data: data,
                accessToken: accessToken
            )
        }
    }

    /// 현재 저장된 사용자 세션을 기준으로 Authorization 헤더 값을 계산합니다.
    /// - Parameter config: Supabase 런타임 기본 구성입니다.
    /// - Returns: 헤더 값, 사용자 토큰 사용 여부, 실제 access token을 포함한 인증 컨텍스트입니다.
    private func resolvedAuthorizationHeader(
        config: SupabaseRuntimeConfig
    ) async -> (
        headerValue: String,
        usedAuthenticatedAccessToken: Bool,
        accessToken: String?
    ) {
        guard let accessToken = await validAccessToken(config: config) else {
            return ("Bearer \(config.anonKey)", false, nil)
        }
        return ("Bearer \(accessToken)", true, accessToken)
    }

    /// 인증 토큰으로 호출한 요청이 401/403을 반환했는지 판정해 세션 무효화 여부를 결정합니다.
    /// - Parameters:
    ///   - statusCode: 응답 HTTP 상태 코드입니다.
    ///   - endpoint: 인증 실패가 발생한 Supabase 엔드포인트입니다.
    ///   - usedAuthenticatedAccessToken: 해당 요청이 사용자 access token으로 호출됐는지 여부입니다.
    ///   - accessToken: 해당 요청에 사용한 사용자 access token 문자열입니다.
    ///   - config: Supabase 런타임 기본 구성입니다.
    /// - Returns: 토큰이 실제 만료/무효로 판정되면 `true`, 게이트/권한 이슈면 `false`입니다.
    private func shouldInvalidateTokenSession(
        statusCode: Int,
        endpoint: SupabaseEndpoint,
        usedAuthenticatedAccessToken: Bool,
        accessToken: String?,
        config: SupabaseRuntimeConfig
    ) async -> Bool {
        guard usedAuthenticatedAccessToken else { return false }
        guard statusCode == 401 || statusCode == 403 else { return false }

        if case .auth = endpoint {
            return true
        }

        guard let accessToken, accessToken.isEmpty == false else {
            return false
        }

        let validation = await validateAccessTokenRemotely(accessToken: accessToken, config: config)
        switch validation {
        case .valid:
            #if DEBUG
            print("[SupabaseAuth] preserve local token session: remote auth user check is still valid")
            #endif
            return false
        case .invalid:
            return true
        case .inconclusive:
            #if DEBUG
            print("[SupabaseAuth] skip local token invalidation: remote auth user check inconclusive")
            #endif
            return false
        }
    }

    /// 인증 토큰 호출이 401/403일 때, 서버 게이트 이슈 회피용 anon 재시도를 수행할지 판단합니다.
    /// - Parameters:
    ///   - endpoint: 호출 대상 Supabase 엔드포인트입니다.
    ///   - statusCode: 1차 응답 상태 코드입니다.
    ///   - usedAuthenticatedAccessToken: 1차 요청이 사용자 access token을 사용했는지 여부입니다.
    /// - Returns: allowlist 함수에서만 anon 재시도를 허용하면 `true`입니다.
    private func shouldRetryWithAnonAuthorization(
        endpoint: SupabaseEndpoint,
        statusCode: Int,
        usedAuthenticatedAccessToken: Bool
    ) -> Bool {
        guard usedAuthenticatedAccessToken else { return false }
        guard statusCode == 401 || statusCode == 403 else { return false }
        guard case .function(let functionName) = endpoint else { return false }
        return Self.edgeFunctionAnonRetryAllowlist.contains(functionName)
    }

    /// Edge Function별 인증 우선순위를 판단해 익명 키 선적용 여부를 결정합니다.
    /// - Parameter endpoint: 호출 대상 Supabase 엔드포인트입니다.
    /// - Returns: 익명 키 우선 호출이 필요한 함수면 `true`, 아니면 `false`입니다.
    private func shouldPreferAnonymousAuthorizationForEndpoint(_ endpoint: SupabaseEndpoint) -> Bool {
        guard case .function(let functionName) = endpoint else { return false }
        return Self.edgeFunctionAnonRetryAllowlist.contains(functionName)
    }

    /// `auth/v1/user` 검증으로 현재 access token이 실제 만료/무효인지 확인합니다.
    /// - Parameters:
    ///   - accessToken: 검증할 사용자 access token 문자열입니다.
    ///   - config: Supabase 런타임 기본 구성입니다.
    /// - Returns: 원격 검증 결과(`valid/invalid/inconclusive`)를 반환합니다.
    private func validateAccessTokenRemotely(
        accessToken: String,
        config: SupabaseRuntimeConfig
    ) async -> AccessTokenValidationState {
        let endpoint = SupabaseEndpoint.auth(path: "user")
        let url = endpoint.resolveURL(baseURL: config.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let startedAt = Date()

        do {
            let (_, response) = try await session.data(for: request)
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                return .inconclusive
            }
            if (200..<300).contains(statusCode) {
                return .valid
            }
            if statusCode == 401 || statusCode == 403 {
                return .invalid
            }
            #if DEBUG
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("[SupabaseAuth] auth-user probe status=\(statusCode) elapsed=\(elapsedMs)ms")
            #endif
            return .inconclusive
        } catch {
            #if DEBUG
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("[SupabaseAuth] auth-user probe failed elapsed=\(elapsedMs)ms error=\(error.localizedDescription)")
            #endif
            return .inconclusive
        }
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
            if let tokenSession = refreshed.tokenSession {
                authSessionStore.persistAuthenticatedSession(identity: refreshed.identity, tokenSession: tokenSession)
                metricTracker.track(
                    .syncAuthRefreshSucceeded,
                    userKey: refreshed.identity.userId
                )
                return tokenSession.accessToken
            }
            metricTracker.track(
                .syncAuthRefreshFailed,
                userKey: refreshed.identity.userId,
                payload: ["reason": "missing_token_session_soft_fail"]
            )
            #if DEBUG
            print("[SupabaseAuth] refresh missing token_session: keep current access token and request re-auth lazily")
            #endif
            return current.accessToken
        case .retryableFailure:
            metricTracker.track(
                .syncAuthRefreshFailed,
                userKey: currentIdentityUserId(),
                payload: ["reason": "retryable_failure"]
            )
            #if DEBUG
            print("[SupabaseAuth] refresh retryable-failure: keep current access token for next retry window")
            #endif
            return current.accessToken
        case .terminalFailure:
            authSessionStore.clearTokenSession()
            metricTracker.track(
                .syncAuthRefreshFailed,
                userKey: currentIdentityUserId(),
                payload: ["reason": "terminal_failure_cleared"]
            )
            #if DEBUG
            print("[SupabaseAuth] refresh terminal-failure: clear token session and require re-auth")
            #endif
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            #if DEBUG
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("[SupabaseAuth] xx refresh-token elapsed=\(elapsedMs)ms request-failed error=\(error.localizedDescription)")
            #endif
            return .retryableFailure
        }
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            #if DEBUG
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("[SupabaseAuth] xx refresh-token elapsed=\(elapsedMs)ms invalid-response")
            #endif
            return .retryableFailure
        }

        guard (200..<300).contains(statusCode) else {
            #if DEBUG
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("[SupabaseAuth] <- refresh-token status=\(statusCode) elapsed=\(elapsedMs)ms")
            #endif
            if isTerminalRefreshFailure(statusCode: statusCode, data: data) {
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
            return .retryableFailure
        }
        #if DEBUG
        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        print("[SupabaseAuth] <- refresh-token status=200 elapsed=\(elapsedMs)ms")
        #endif
        return .success(credential)
    }

    /// 토큰 refresh 실패 응답이 즉시 로그아웃해야 하는 종단 오류인지 판정합니다.
    /// - Parameters:
    ///   - statusCode: refresh 엔드포인트 HTTP 상태 코드입니다.
    ///   - data: 실패 응답 바디 데이터입니다.
    /// - Returns: refresh token 무효/폐기 계열이면 `true`, 네트워크·일시 오류 성격이면 `false`입니다.
    private func isTerminalRefreshFailure(statusCode: Int, data: Data) -> Bool {
        guard statusCode == 400 || statusCode == 401 else {
            return false
        }
        let normalized = refreshFailureMessage(from: data)
        guard normalized.isEmpty == false else {
            return false
        }
        if normalized.contains("invalid_grant") { return true }
        if normalized.contains("refresh token") && normalized.contains("invalid") { return true }
        if normalized.contains("refresh token") && normalized.contains("expired") { return true }
        if normalized.contains("refresh token") && normalized.contains("not found") { return true }
        return false
    }

    /// refresh 실패 응답 바디를 소문자 비교용 문자열로 정규화합니다.
    /// - Parameter data: refresh 엔드포인트 실패 응답 바디 데이터입니다.
    /// - Returns: `error_code/message/error_description` 우선순위로 추출한 정규화 문자열입니다.
    private func refreshFailureMessage(from data: Data) -> String {
        guard let decoded = try? JSONDecoder().decode(SupabaseAuthResponseDTO.self, from: data) else {
            return ""
        }
        let message = decoded.errorCode
            ?? decoded.errorDescription
            ?? decoded.error
            ?? decoded.message
            ?? decoded.msg
            ?? ""
        return message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
    let suppressionReason: String?
    let delayMinutes: Int?
    let requiredMinSample: Int?
    let obfuscationMeters: Int?
    let abuseReason: String?
    let abuseScore: Double?
    let sanctionLevel: String?
    let sanctionUntilEpoch: TimeInterval?
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
        lhs.suppressionReason == rhs.suppressionReason &&
        lhs.delayMinutes == rhs.delayMinutes &&
        lhs.requiredMinSample == rhs.requiredMinSample &&
        lhs.obfuscationMeters == rhs.obfuscationMeters &&
        lhs.abuseReason == rhs.abuseReason &&
        lhs.abuseScore == rhs.abuseScore &&
        lhs.sanctionLevel == rhs.sanctionLevel &&
        lhs.sanctionUntilEpoch == rhs.sanctionUntilEpoch &&
        lhs.writeApplied == rhs.writeApplied
    }
}

protocol NearbyPresenceServiceProtocol {
    /// 현재 사용자 범위의 canonical visibility 상태를 읽습니다.
    /// - Parameter userId: 조회 대상 사용자 UUID 문자열입니다.
    /// - Returns: 서버가 보유한 현재 visibility 상태와 갱신 시각입니다.
    func getVisibility(userId: String) async throws -> PrivacyVisibilitySyncResultDTO
    /// 현재 사용자 범위의 visibility 상태를 변경하고 canonical 결과를 반환합니다.
    /// - Parameters:
    ///   - userId: 변경 대상 사용자 UUID 문자열입니다.
    ///   - enabled: 서버에 반영할 목표 공유 상태입니다.
    /// - Returns: 서버가 최종 반영한 canonical visibility 상태와 갱신 시각입니다.
    func setVisibility(userId: String, enabled: Bool) async throws -> PrivacyVisibilitySyncResultDTO
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
    ///   - deviceKey: 사용자 디바이스/설치 단위 rate-limit 판정용 키입니다.
    /// - Returns: 서버에 반영된 최신 라이브 프레즌스 행입니다. visibility OFF 등으로 저장이 생략되면 `nil`입니다.
    func upsertLivePresence(
        userId: String,
        sessionId: String?,
        latitude: Double,
        longitude: Double,
        speedMetersPerSecond: Double?,
        sequence: Int?,
        idempotencyKey: String?,
        deviceKey: String?
    ) async throws -> WalkLivePresenceDTO?
    /// 지정한 viewport 범위의 실시간 프레즌스 목록을 조회합니다.
    /// - Parameters:
    ///   - minLatitude: 조회 최소 위도 경계입니다.
    ///   - maxLatitude: 조회 최대 위도 경계입니다.
    ///   - minLongitude: 조회 최소 경도 경계입니다.
    ///   - maxLongitude: 조회 최대 경도 경계입니다.
    ///   - maxRows: 최대 반환 row 수입니다.
    ///   - privacyMode: 조회 프라이버시 모드(`public`/`private`/`all`)입니다.
    ///   - requesterUserId: 요청자 사용자 UUID 문자열입니다. 자기 row의 예외 처리 판단에 사용됩니다.
    ///   - excludedUserIds: 차단/숨김 등으로 즉시 제외할 사용자 UUID 목록입니다.
    /// - Returns: viewport 범위와 프라이버시 필터가 적용된 실시간 프레즌스 목록입니다.
    func getLivePresence(
        minLatitude: Double,
        maxLatitude: Double,
        minLongitude: Double,
        maxLongitude: Double,
        maxRows: Int,
        privacyMode: String,
        requesterUserId: String?,
        excludedUserIds: [String]
    ) async throws -> [WalkLivePresenceDTO]
}

/// nearby presence 서버가 반환하는 canonical visibility 상태 DTO입니다.
struct PrivacyVisibilitySyncResultDTO: Equatable {
    let enabled: Bool
    let updatedAtEpoch: TimeInterval?
    let requestId: String?
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
