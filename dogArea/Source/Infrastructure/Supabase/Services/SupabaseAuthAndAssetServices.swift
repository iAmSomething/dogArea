import Foundation

extension Bundle {
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
                return "메일 요청이 많아 잠시 뒤 다시 시도할 수 있어요.\(retryText)"
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
                let normalizedRateLimitMessage = normalizedAuthRateLimitMessage(
                    path: path,
                    upstreamMessage: responseMessage,
                    errorCode: responseErrorCode
                )
                throw SupabaseAuthError.rateLimited(
                    message: normalizedRateLimitMessage,
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

    /// Auth 429 응답을 사용자 안내용 메시지로 정규화합니다.
    /// - Parameters:
    ///   - path: 요청한 Auth 엔드포인트 경로(`signup`, `token` 등)입니다.
    ///   - upstreamMessage: 서버 응답 본문에서 추출한 원본 메시지입니다.
    ///   - errorCode: Supabase 오류 코드(`x-sb-error-code` 포함)입니다.
    /// - Returns: 사용자에게 노출할 429 안내 메시지입니다.
    private func normalizedAuthRateLimitMessage(
        path: String,
        upstreamMessage: String?,
        errorCode: String?
    ) -> String? {
        let trimmedMessage: String? = {
            guard let raw = upstreamMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
                  raw.isEmpty == false else {
                return nil
            }
            return raw
        }()

        if errorCode == "over_email_send_rate_limit" {
            return trimmedMessage ?? "회원가입 인증 메일 발송 한도를 초과했습니다."
        }

        if let trimmedMessage,
           trimmedMessage.contains("인증에 실패했습니다") == false {
            return trimmedMessage
        }

        switch path {
        case "signup":
            return "회원가입 요청이 너무 자주 발생해 일시적으로 제한되었습니다."
        case "token":
            return "로그인 요청이 너무 자주 발생해 일시적으로 제한되었습니다."
        default:
            return "인증 요청이 너무 많아 일시적으로 제한되었습니다."
        }
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

    /// 프로필 이미지 업로드 실패 상태 코드를 사용자 메시지로 변환합니다.
    /// - Parameters:
    ///   - statusCode: Edge Function이 반환한 HTTP 상태 코드입니다.
    ///   - imageKind: 업로드 대상 종류(`user`/`pet`)입니다.
    /// - Returns: 설정 화면에 바로 노출할 수 있는 지역화 메시지입니다.
    private func localizedUploadFailureMessage(statusCode: Int, imageKind: String) -> String {
        let assetName = imageKind == "pet" ? "반려견 프로필 사진" : "프로필 사진"
        switch statusCode {
        case 400:
            return "\(assetName) 형식이 올바르지 않거나 너무 커서 업로드할 수 없어요. 이미지를 다시 선택해 주세요."
        case 401, 403:
            return "\(assetName) 업로드 권한을 확인하지 못했어요. 다시 로그인한 뒤 다시 시도해 주세요."
        default:
            return "\(assetName) 업로드에 실패했어요. 잠시 후 다시 시도해 주세요. (\(statusCode))"
        }
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
        let responseData: Data
        do {
            responseData = try await client.request(
                .function(name: "upload-profile-image"),
                method: .post,
                body: requestBody
            )
        } catch let httpError as SupabaseHTTPError {
            if case .unexpectedStatusCode(let statusCode) = httpError {
                throw SupabaseAssetError.serverError(
                    localizedUploadFailureMessage(statusCode: statusCode, imageKind: imageKind)
                )
            }
            throw SupabaseAssetError.serverError("프로필 사진 업로드 요청을 완료하지 못했어요. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.")
        }
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
