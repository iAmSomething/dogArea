import Foundation
import CoreLocation

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
        let sequence: Int?
        let idempotency_key: String?
        let updated_at: String?
        let expires_at: String?
        let privacy_mode: String?
        let suppression_reason: String?
        let delay_minutes: Int?
        let required_min_sample: Int?
        let obfuscation_meters: Int?
        let abuse_reason: String?
        let abuse_score: Double?
        let sanction_level: String?
        let sanction_until: String?
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
    ///   - deviceKey: 디바이스 단위 호출 빈도 방어를 위한 식별 키입니다.
    /// - Returns: 서버가 반영한 최신 라이브 presence 행입니다. 공유 OFF로 생략되면 `nil`입니다.
    func upsertLivePresence(
        userId: String,
        sessionId: String?,
        latitude: Double,
        longitude: Double,
        speedMetersPerSecond: Double?,
        sequence: Int?,
        idempotencyKey: String?,
        deviceKey: String? = nil
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
        if let deviceKey, deviceKey.isEmpty == false {
            payload["deviceKey"] = deviceKey
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
    ///   - requesterUserId: 요청자 사용자 UUID 문자열입니다.
    ///   - excludedUserIds: 즉시 비노출할 사용자 UUID 목록입니다.
    /// - Returns: 만료/프라이버시 필터가 적용된 실시간 presence 목록입니다.
    func getLivePresence(
        minLatitude: Double,
        maxLatitude: Double,
        minLongitude: Double,
        maxLongitude: Double,
        maxRows: Int = 200,
        privacyMode: String = "public",
        requesterUserId: String? = nil,
        excludedUserIds: [String] = []
    ) async throws -> [WalkLivePresenceDTO] {
        var payload: [String: Any] = [
            "action": "get_live_presence",
            "minLat": minLatitude,
            "maxLat": maxLatitude,
            "minLng": minLongitude,
            "maxLng": maxLongitude,
            "maxRows": maxRows,
            "privacyMode": privacyMode
        ]
        if let requesterUserId, requesterUserId.isEmpty == false {
            payload["userId"] = requesterUserId
        }
        if excludedUserIds.isEmpty == false {
            payload["excludedUserIds"] = excludedUserIds
        }

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
        let effectiveIdempotencyKey = row.idempotency_key ?? "\(row.owner_user_id):\(row.session_id):\(row.updated_at ?? "0")"
        return WalkLivePresenceDTO(
            ownerUserId: row.owner_user_id,
            sessionId: row.session_id,
            coordinate: CLLocationCoordinate2D(latitude: row.lat_rounded, longitude: row.lng_rounded),
            speedMetersPerSecond: row.speed_mps,
            sequence: row.sequence ?? 0,
            idempotencyKey: effectiveIdempotencyKey,
            updatedAtEpoch: SupabaseISO8601.parseEpoch(row.updated_at) ?? 0,
            expiresAtEpoch: SupabaseISO8601.parseEpoch(row.expires_at) ?? 0,
            privacyMode: row.privacy_mode,
            suppressionReason: row.suppression_reason,
            delayMinutes: row.delay_minutes,
            requiredMinSample: row.required_min_sample,
            obfuscationMeters: row.obfuscation_meters,
            abuseReason: row.abuse_reason,
            abuseScore: row.abuse_score,
            sanctionLevel: row.sanction_level,
            sanctionUntilEpoch: SupabaseISO8601.parseEpoch(row.sanction_until),
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
            "payload": [
                "period_type": period.rawValue,
                "top_n": safeTopN,
                "now_ts": ISO8601DateFormatter().string(from: Date())
            ]
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
            "in_now_ts": ISO8601DateFormatter().string(from: now)
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
            "payload": [
                "period_type": RivalLeaderboardPeriod.week.rawValue,
                "top_n": 50,
                "now_ts": ISO8601DateFormatter().string(from: now)
            ]
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

