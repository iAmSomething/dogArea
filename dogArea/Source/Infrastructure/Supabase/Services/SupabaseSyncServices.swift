import Foundation

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

