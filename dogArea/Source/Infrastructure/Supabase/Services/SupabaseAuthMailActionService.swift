import Foundation

enum AuthMailDispatchRequest: Equatable {
    case signupConfirmation(email: String)
    case passwordReset(email: String)
    case emailChange(email: String)

    var actionType: AuthMailActionType {
        switch self {
        case .signupConfirmation:
            return .signupConfirmation
        case .passwordReset:
            return .passwordReset
        case .emailChange:
            return .emailChange
        }
    }

    var normalizedEmail: String {
        switch self {
        case .signupConfirmation(let email), .passwordReset(let email), .emailChange(let email):
            return email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    var endpoint: SupabaseEndpoint {
        switch self {
        case .signupConfirmation, .emailChange:
            return .auth(path: "resend")
        case .passwordReset:
            return .auth(path: "recover")
        }
    }

    var payload: [String: String] {
        switch self {
        case .signupConfirmation(let email):
            return [
                "type": "signup",
                "email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            ]
        case .passwordReset(let email):
            return [
                "email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            ]
        case .emailChange(let email):
            return [
                "type": "email_change",
                "email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            ]
        }
    }
}

protocol AuthMailActionDispatching {
    /// 메일 액션 요청을 서버로 전송합니다.
    /// - Parameter request: 발송할 메일 액션 요청입니다.
    func send(_ request: AuthMailDispatchRequest) async throws
}

final class SupabaseAuthMailActionService: AuthMailActionDispatching {
    private let session: URLSession
    private let configLoader: () -> SupabaseRuntimeConfig?

    /// Supabase Auth 메일 액션 디스패처를 초기화합니다.
    /// - Parameters:
    ///   - session: HTTP 요청에 사용할 URLSession입니다.
    ///   - configLoader: 런타임 Supabase 설정을 읽어오는 클로저입니다.
    init(
        session: URLSession = .shared,
        configLoader: @escaping () -> SupabaseRuntimeConfig? = { SupabaseRuntimeConfig.load() }
    ) {
        self.session = session
        self.configLoader = configLoader
    }

    func send(_ request: AuthMailDispatchRequest) async throws {
        guard let config = configLoader() else {
            throw SupabaseAuthError.notConfigured
        }

        let url = request.endpoint.resolveURL(baseURL: config.baseURL)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HTTPMethod.post.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        urlRequest.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request.payload)

        #if DEBUG
        print("[AuthMail] -> action=\(request.actionType.analyticsKey) endpoint=\(url.absoluteString) email=\(request.normalizedEmail)")
        #endif
        let startedAt = Date()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            #if DEBUG
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            print("[AuthMail] xx action=\(request.actionType.analyticsKey) elapsed=\(elapsedMs)ms error=\(error.localizedDescription)")
            #endif
            throw SupabaseAuthError.requestFailed(request.actionType.defaultFailureMessage())
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthError.responseDecodeFailed
        }

        let statusCode = httpResponse.statusCode
        let errorPayload = decodeLooseAuthErrorPayload(from: data)
        let errorCode = errorPayload.errorCode ?? httpResponse.value(forHTTPHeaderField: "x-sb-error-code")
        let retryAfterSeconds = retryAfterSeconds(from: httpResponse)

        #if DEBUG
        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        let bodyPreview = String(decoding: data.prefix(180), as: UTF8.self)
        print("[AuthMail] <- action=\(request.actionType.analyticsKey) status=\(statusCode) elapsed=\(elapsedMs)ms errorCode=\(errorCode ?? "none") retryAfter=\(retryAfterSeconds.map(String.init) ?? "none") body=\(bodyPreview)")
        #endif

        guard (200..<300).contains(statusCode) else {
            if statusCode == 429 {
                throw SupabaseAuthError.rateLimited(
                    message: normalizedRateLimitMessage(for: request),
                    errorCode: errorCode,
                    retryAfterSeconds: retryAfterSeconds
                )
            }
            throw SupabaseAuthError.requestFailed(
                normalizedFailureMessage(for: request, upstreamMessage: errorPayload.message)
            )
        }
    }

    /// 서버가 제공한 원본 오류와 액션 타입을 바탕으로 사용자용 실패 문구를 정규화합니다.
    /// - Parameters:
    ///   - request: 실패한 메일 액션 요청입니다.
    ///   - upstreamMessage: 서버 응답에서 추출한 원본 오류 메시지입니다.
    /// - Returns: 내부 운영 용어를 제거한 사용자용 실패 안내 문구입니다.
    private func normalizedFailureMessage(
        for request: AuthMailDispatchRequest,
        upstreamMessage: String?
    ) -> String {
        let trimmedMessage = upstreamMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedMessage, trimmedMessage.isEmpty == false,
           trimmedMessage.contains("SMTP") == false,
           trimmedMessage.contains("Rate Limit") == false {
            return trimmedMessage
        }
        return request.actionType.defaultFailureMessage()
    }

    /// 429 응답을 메일 액션별 사용자 안내 문구로 정규화합니다.
    /// - Parameter request: rate-limit이 발생한 메일 액션 요청입니다.
    /// - Returns: 사용자에게 보여줄 보수적 429 안내 문구입니다.
    private func normalizedRateLimitMessage(for request: AuthMailDispatchRequest) -> String {
        switch request.actionType {
        case .signupConfirmation:
            return "인증 메일 요청이 많아 잠시 뒤 다시 보낼 수 있어요."
        case .passwordReset:
            return "재설정 메일 요청이 많아 잠시 뒤 다시 보낼 수 있어요."
        case .emailChange:
            return "변경 확인 메일 요청이 많아 잠시 뒤 다시 보낼 수 있어요."
        }
    }

    /// Auth 오류 응답을 느슨하게 디코딩해 메시지와 오류 코드를 추출합니다.
    /// - Parameter data: 서버가 반환한 응답 바디 데이터입니다.
    /// - Returns: 메시지와 오류 코드의 느슨한 파싱 결과입니다.
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

    /// HTTP 응답에서 `Retry-After` 헤더를 초 단위 값으로 해석합니다.
    /// - Parameter response: Supabase Auth HTTP 응답 객체입니다.
    /// - Returns: 유효한 `Retry-After` 값이 있으면 초 단위 정수를, 없으면 `nil`을 반환합니다.
    private func retryAfterSeconds(from response: HTTPURLResponse) -> Int? {
        guard let rawValue = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              rawValue.isEmpty == false,
              let seconds = Int(rawValue),
              seconds >= 0 else {
            return nil
        }
        return seconds
    }
}
