import Foundation

struct FeatureControlService: FeatureFlagRemoteServiceProtocol {
    static let shared = FeatureControlService()
    private static let functionUnavailableUntilKey = "feature.control.unavailable.until.v1"
    private static let functionUnavailableCooldownSeconds: TimeInterval = 10 * 60

    private let client: SupabaseHTTPClient
    private let cooldownStore: UserDefaults

    init(
        client: SupabaseHTTPClient = .live,
        cooldownStore: UserDefaults = .standard
    ) {
        self.client = client
        self.cooldownStore = cooldownStore
    }

    func post(payload: [String: Any]) async throws -> Data {
        guard isFunctionTemporarilyUnavailable(now: Date()) == false else {
            #if DEBUG
            print("[FeatureControl] blocked: function cooldown active")
            #endif
            throw SupabaseHTTPError.notConfigured
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
        do {
            let data = try await client.request(
                .function(name: "feature-control"),
                method: .post,
                bodyData: body
            )
            clearFunctionUnavailableMarker()
            return data
        } catch let error as SupabaseHTTPError {
            if case .unexpectedStatusCode(404) = error {
                markFunctionTemporarilyUnavailable(now: Date())
                throw SupabaseHTTPError.notConfigured
            }
            throw error
        }
    }

    func postFireAndForget(payload: [String: Any]) {
        guard isFunctionTemporarilyUnavailable(now: Date()) == false else {
            return
        }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        Task.detached(priority: .utility) {
            do {
                _ = try await client.request(
                    .function(name: "feature-control"),
                    method: .post,
                    bodyData: body
                )
                clearFunctionUnavailableMarker()
            } catch let error as SupabaseHTTPError {
                if case .unexpectedStatusCode(404) = error {
                    markFunctionTemporarilyUnavailable(now: Date())
                }
            } catch {
                return
            }
        }
    }

    /// `feature-control` 함수가 최근 404로 비가용 처리됐는지 확인합니다.
    /// - Parameter now: 쿨다운 만료 판정 기준 시각입니다.
    /// - Returns: 쿨다운 기간이 남아 있으면 `true`, 아니면 `false`입니다.
    private func isFunctionTemporarilyUnavailable(now: Date) -> Bool {
        let unavailableUntil = cooldownStore.double(forKey: Self.functionUnavailableUntilKey)
        return unavailableUntil > now.timeIntervalSince1970
    }

    /// `feature-control` 함수 404 감지 시 재시도 폭주를 막기 위해 쿨다운 마커를 기록합니다.
    /// - Parameter now: 쿨다운 만료시각 계산 기준 시각입니다.
    private func markFunctionTemporarilyUnavailable(now: Date) {
        let unavailableUntil = now.timeIntervalSince1970 + Self.functionUnavailableCooldownSeconds
        cooldownStore.set(unavailableUntil, forKey: Self.functionUnavailableUntilKey)
        #if DEBUG
        print("[FeatureControl] marked unavailable for \(Int(Self.functionUnavailableCooldownSeconds))s due to 404")
        #endif
    }

    /// `feature-control` 함수 호출이 성공하면 404 쿨다운 마커를 제거합니다.
    private func clearFunctionUnavailableMarker() {
        cooldownStore.removeObject(forKey: Self.functionUnavailableUntilKey)
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

