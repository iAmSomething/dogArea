import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

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
    private struct ResponseDTO {
        let todayTileCount: Int?
        let weeklyTileCount: Int?
        let defenseScheduledTileCount: Int?
        let scoreUpdatedAt: String?
        let refreshedAt: String?
        let hasData: Bool?
    }

    private struct LegacyResponseDTO: Decodable {
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

    private struct EnvelopeResponseDTO: Decodable {
        struct SummaryDTO: Decodable {
            let todayTileCount: Int?
            let weeklyTileCount: Int?
            let defenseScheduledTileCount: Int?
            let scoreUpdatedAt: String?

            enum CodingKeys: String, CodingKey {
                case todayTileCount = "today_tile_count"
                case weeklyTileCount = "weekly_tile_count"
                case defenseScheduledTileCount = "defense_scheduled_tile_count"
                case scoreUpdatedAt = "score_updated_at"
            }
        }

        let hasData: Bool?
        let refreshedAt: String?
        let summary: SummaryDTO?

        enum CodingKeys: String, CodingKey {
            case hasData = "has_data"
            case refreshedAt = "refreshed_at"
            case summary
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
        let decoded: ResponseDTO
        do {
            decoded = try await fetchCanonicalSummary(now: now)
        } catch {
            decoded = try await fetchLegacySummary(now: now)
        }
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

    /// canonical wrapper 요청으로 영역 요약 RPC를 조회합니다.
    /// - Parameter now: 서버 집계 기준 시각입니다.
    /// - Returns: envelope 또는 legacy 응답을 정규화한 영역 요약 응답입니다.
    private func fetchCanonicalSummary(now: Date) async throws -> ResponseDTO {
        let payload: [String: Any] = [
            "payload": [
                "in_now_ts": ISO8601DateFormatter().string(from: now)
            ]
        ]
        let data = try await client.request(
            .rest(path: "rpc/rpc_get_widget_territory_summary"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )
        return try decodeSummaryResponse(data: data)
    }

    /// legacy positional 요청으로 영역 요약 RPC를 조회합니다.
    /// - Parameter now: 서버 집계 기준 시각입니다.
    /// - Returns: legacy top-level 응답을 정규화한 영역 요약 응답입니다.
    private func fetchLegacySummary(now: Date) async throws -> ResponseDTO {
        let payload: [String: Any] = [
            "now_ts": ISO8601DateFormatter().string(from: now)
        ]
        let data = try await client.request(
            .rest(path: "rpc/rpc_get_widget_territory_summary"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )
        return try decodeSummaryResponse(data: data)
    }

    /// RPC 응답이 canonical envelope 또는 legacy top-level 어느 형태든 단일 요약 객체로 파싱합니다.
    /// - Parameter data: RPC 원시 응답 데이터입니다.
    /// - Returns: 앱 DTO 변환에 사용할 정규화된 영역 요약 응답입니다.
    private func decodeSummaryResponse(data: Data) throws -> ResponseDTO {
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(EnvelopeResponseDTO.self, from: data),
           let summary = envelope.summary {
            return ResponseDTO(
                todayTileCount: summary.todayTileCount,
                weeklyTileCount: summary.weeklyTileCount,
                defenseScheduledTileCount: summary.defenseScheduledTileCount,
                scoreUpdatedAt: summary.scoreUpdatedAt,
                refreshedAt: envelope.refreshedAt,
                hasData: envelope.hasData
            )
        }
        if let object = try? decoder.decode(LegacyResponseDTO.self, from: data) {
            return ResponseDTO(
                todayTileCount: object.todayTileCount,
                weeklyTileCount: object.weeklyTileCount,
                defenseScheduledTileCount: object.defenseScheduledTileCount,
                scoreUpdatedAt: object.scoreUpdatedAt,
                refreshedAt: object.refreshedAt,
                hasData: object.hasData
            )
        }
        if let rows = try? decoder.decode([LegacyResponseDTO].self, from: data),
           let first = rows.first {
            return ResponseDTO(
                todayTileCount: first.todayTileCount,
                weeklyTileCount: first.weeklyTileCount,
                defenseScheduledTileCount: first.defenseScheduledTileCount,
                scoreUpdatedAt: first.scoreUpdatedAt,
                refreshedAt: first.refreshedAt,
                hasData: first.hasData
            )
        }
        throw SupabaseHTTPError.invalidResponse
    }
}

final class DefaultTerritoryWidgetSnapshotSyncService: TerritoryWidgetSnapshotSyncing {
    private let summaryService: TerritoryWidgetSummaryServiceProtocol
    private let snapshotStore: TerritoryWidgetSnapshotStoring
    private let userSessionStore: UserSessionStoreProtocol
    private let walkRepository: WalkRepositoryProtocol
    private let areaReferenceRepository: AreaReferenceRepository
    private let goalContextService: TerritoryWidgetGoalContextServicing
    private let preferenceStore: UserDefaults
    private let syncTTL: TimeInterval
    private let staleGraceInterval: TimeInterval

    /// 영역 위젯 스냅샷 동기화 서비스를 생성합니다.
    /// - Parameters:
    ///   - summaryService: 서버 요약 RPC 호출 서비스입니다.
    ///   - snapshotStore: 앱 그룹 기반 위젯 스냅샷 저장소입니다.
    ///   - userSessionStore: 현재 로그인 사용자 컨텍스트 조회 저장소입니다.
    ///   - walkRepository: 선택 반려견 기준 로컬 산책 영역을 읽어오는 저장소입니다.
    ///   - areaReferenceRepository: 다음 목표 계산에 사용할 비교 구역 저장소입니다.
    ///   - goalContextService: 선택 반려견 기준 목표 문맥을 계산하는 서비스입니다.
    ///   - preferenceStore: 마지막 동기화 메타데이터를 저장할 기본 설정 저장소입니다.
    ///   - syncTTL: RPC 재조회 최소 간격(초)입니다.
    ///   - staleGraceInterval: 오프라인 캐시를 허용할 최대 유예 시간(초)입니다.
    init(
        summaryService: TerritoryWidgetSummaryServiceProtocol = TerritoryWidgetSummaryService(),
        snapshotStore: TerritoryWidgetSnapshotStoring = DefaultTerritoryWidgetSnapshotStore.shared,
        userSessionStore: UserSessionStoreProtocol = DefaultUserSessionStore.shared,
        walkRepository: WalkRepositoryProtocol = WalkRepositoryContainer.shared,
        areaReferenceRepository: AreaReferenceRepository = SupabaseAreaReferenceRepository.shared,
        goalContextService: TerritoryWidgetGoalContextServicing = TerritoryWidgetGoalContextService(),
        preferenceStore: UserDefaults = .standard,
        syncTTL: TimeInterval = 15 * 60,
        staleGraceInterval: TimeInterval = 6 * 60 * 60
    ) {
        self.summaryService = summaryService
        self.snapshotStore = snapshotStore
        self.userSessionStore = userSessionStore
        self.walkRepository = walkRepository
        self.areaReferenceRepository = areaReferenceRepository
        self.goalContextService = goalContextService
        self.preferenceStore = preferenceStore
        self.syncTTL = syncTTL
        self.staleGraceInterval = staleGraceInterval
    }

    /// 서버 요약을 조회해 위젯 공유 스냅샷을 갱신합니다.
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
            let polygons = walkRepository.fetchPolygons()
            async let areaReferenceSnapshot = areaReferenceRepository.fetchSnapshot()
            let summary = try await summaryService.fetchSummary(now: now)
            let goalContext = goalContextService.makeGoalContext(
                userInfo: user,
                polygons: polygons,
                areaReferenceSnapshot: await areaReferenceSnapshot
            )
            saveMemberSnapshot(
                summary: summary,
                goalContext: goalContext,
                contextKey: contextKey,
                now: now
            )
        } catch {
            saveFailureSnapshot(contextKey: contextKey, now: now)
        }
    }

    /// TTL과 현재 반려견 컨텍스트를 기준으로 이번 동기화를 수행할지 판단합니다.
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
    /// - Returns: 다계정/다견 전환 시 stale 스냅샷을 구분할 컨텍스트 키 문자열입니다.
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
        let snapshot = TerritoryWidgetSnapshot(
            status: .guestLocked,
            message: "로그인 후 오늘/주간 영역 현황과 다음 목표를 위젯에서 확인할 수 있어요.",
            summary: nil,
            contextKey: "guest",
            updatedAt: now.timeIntervalSince1970
        )
        save(snapshot, now: now)
    }

    /// 서버 요약 응답을 회원 상태 스냅샷으로 저장합니다.
    /// - Parameters:
    ///   - summary: 서버에서 조회한 최신 영역 요약 DTO입니다.
    ///   - goalContext: 선택 반려견 기준으로 계산한 목표 문맥입니다.
    ///   - contextKey: 사용자/반려견 컨텍스트 키입니다.
    ///   - now: 저장 시각입니다.
    private func saveMemberSnapshot(
        summary: TerritoryWidgetSummaryDTO,
        goalContext: TerritoryWidgetGoalContextSnapshot,
        contextKey: String,
        now: Date
    ) {
        let hasMeaningfulGoalContext = goalContext.status == .ready || goalContext.status == .completed
        let snapshotStatus: TerritoryWidgetSnapshotStatus =
            (summary.hasData || hasMeaningfulGoalContext) ? .memberReady : .emptyData
        let snapshotMessage: String
        if summary.hasData || goalContext.status == .ready {
            snapshotMessage = "오늘/주간 지표와 다음 목표를 함께 표시합니다."
        } else if goalContext.status == .completed {
            snapshotMessage = "비교 구역 기준은 모두 달성했고, 최신 타일 지표를 함께 표시합니다."
        } else {
            snapshotMessage = "첫 산책 후 다음 목표와 영역 요약을 함께 보여드릴게요."
        }

        let snapshot = TerritoryWidgetSnapshot(
            status: snapshotStatus,
            message: snapshotMessage,
            summary: TerritoryWidgetSummarySnapshot(
                todayTileCount: summary.todayTileCount,
                weeklyTileCount: summary.weeklyTileCount,
                defenseScheduledTileCount: summary.defenseScheduledTileCount,
                scoreUpdatedAt: summary.scoreUpdatedAt,
                refreshedAt: summary.refreshedAt,
                goalContext: goalContext
            ),
            contextKey: contextKey,
            updatedAt: now.timeIntervalSince1970
        )
        save(snapshot, now: now)
    }

    /// 서버 조회 실패 시 마지막 성공 스냅샷 기반 상태로 저장합니다.
    /// - Parameters:
    ///   - contextKey: 현재 사용자/반려견 컨텍스트 키입니다.
    ///   - now: 저장 시각입니다.
    private func saveFailureSnapshot(contextKey: String, now: Date) {
        let current = snapshotStore.load()
        let cachedSummary = current.summary

        if current.contextKey == contextKey, let cachedSummary {
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
                    contextKey: contextKey,
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
                contextKey: contextKey,
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
    private struct ResponseDTO {
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
    }

    private struct LegacyResponseDTO: Decodable {
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

    private struct EnvelopeResponseDTO: Decodable {
        struct ContextDTO: Decodable {
            let isCached: Bool?
            let privacyMode: String?
            let suppressionReason: String?

            enum CodingKeys: String, CodingKey {
                case isCached = "is_cached"
                case privacyMode = "privacy_mode"
                case suppressionReason = "suppression_reason"
            }
        }

        struct SummaryDTO: Decodable {
            let signalLevel: String?
            let highCells: Int?
            let mediumCells: Int?
            let lowCells: Int?
            let delayMinutes: Int?
            let privacyMode: String?
            let suppressionReason: String?
            let guideCopy: String?

            enum CodingKeys: String, CodingKey {
                case signalLevel = "signal_level"
                case highCells = "high_cells"
                case mediumCells = "medium_cells"
                case lowCells = "low_cells"
                case delayMinutes = "delay_minutes"
                case privacyMode = "privacy_mode"
                case suppressionReason = "suppression_reason"
                case guideCopy = "guide_copy"
            }
        }

        let hasData: Bool?
        let refreshedAt: String?
        let context: ContextDTO?
        let summary: SummaryDTO?

        enum CodingKeys: String, CodingKey {
            case hasData = "has_data"
            case refreshedAt = "refreshed_at"
            case context
            case summary
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
        let decoded: ResponseDTO
        do {
            decoded = try await fetchCanonicalSummary(radiusKm: radiusKm, now: now)
        } catch {
            decoded = try await fetchLegacySummary(radiusKm: radiusKm, now: now)
        }
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

    /// canonical wrapper 요청으로 핫스팟 요약 RPC를 조회합니다.
    /// - Parameters:
    ///   - radiusKm: 사용자 주변 집계 반경(km)입니다.
    ///   - now: 서버 집계 기준 시각입니다.
    /// - Returns: envelope 또는 legacy 응답을 정규화한 핫스팟 요약 응답입니다.
    private func fetchCanonicalSummary(radiusKm: Double, now: Date) async throws -> ResponseDTO {
        let payload: [String: Any] = [
            "payload": [
                "in_radius_km": min(5.0, max(0.3, radiusKm)),
                "in_now_ts": ISO8601DateFormatter().string(from: now)
            ]
        ]
        let data = try await client.request(
            .rest(path: "rpc/rpc_get_widget_hotspot_summary"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )
        return try decodeSummaryResponse(data: data)
    }

    /// legacy positional 요청으로 핫스팟 요약 RPC를 조회합니다.
    /// - Parameters:
    ///   - radiusKm: 사용자 주변 집계 반경(km)입니다.
    ///   - now: 서버 집계 기준 시각입니다.
    /// - Returns: legacy top-level 응답을 정규화한 핫스팟 요약 응답입니다.
    private func fetchLegacySummary(radiusKm: Double, now: Date) async throws -> ResponseDTO {
        let payload: [String: Any] = [
            "radius_km": min(5.0, max(0.3, radiusKm)),
            "now_ts": ISO8601DateFormatter().string(from: now)
        ]
        let data = try await client.request(
            .rest(path: "rpc/rpc_get_widget_hotspot_summary"),
            method: .post,
            bodyData: try JSONSerialization.data(withJSONObject: payload)
        )
        return try decodeSummaryResponse(data: data)
    }

    /// RPC 응답이 canonical envelope 또는 legacy top-level 어느 형태든 단일 요약 객체로 파싱합니다.
    /// - Parameter data: RPC 원시 응답 데이터입니다.
    /// - Returns: 앱 DTO 변환에 사용할 정규화된 핫스팟 요약 응답입니다.
    private func decodeSummaryResponse(data: Data) throws -> ResponseDTO {
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(EnvelopeResponseDTO.self, from: data),
           let summary = envelope.summary {
            return ResponseDTO(
                signalLevel: summary.signalLevel,
                highCells: summary.highCells,
                mediumCells: summary.mediumCells,
                lowCells: summary.lowCells,
                delayMinutes: summary.delayMinutes,
                privacyMode: summary.privacyMode ?? envelope.context?.privacyMode,
                suppressionReason: summary.suppressionReason ?? envelope.context?.suppressionReason,
                guideCopy: summary.guideCopy,
                hasData: envelope.hasData,
                isCached: envelope.context?.isCached,
                refreshedAt: envelope.refreshedAt
            )
        }
        if let object = try? decoder.decode(LegacyResponseDTO.self, from: data) {
            return ResponseDTO(
                signalLevel: object.signalLevel,
                highCells: object.highCells,
                mediumCells: object.mediumCells,
                lowCells: object.lowCells,
                delayMinutes: object.delayMinutes,
                privacyMode: object.privacyMode,
                suppressionReason: object.suppressionReason,
                guideCopy: object.guideCopy,
                hasData: object.hasData,
                isCached: object.isCached,
                refreshedAt: object.refreshedAt
            )
        }
        if let rows = try? decoder.decode([LegacyResponseDTO].self, from: data),
           let first = rows.first {
            return ResponseDTO(
                signalLevel: first.signalLevel,
                highCells: first.highCells,
                mediumCells: first.mediumCells,
                lowCells: first.lowCells,
                delayMinutes: first.delayMinutes,
                privacyMode: first.privacyMode,
                suppressionReason: first.suppressionReason,
                guideCopy: first.guideCopy,
                hasData: first.hasData,
                isCached: first.isCached,
                refreshedAt: first.refreshedAt
            )
        }
        throw SupabaseHTTPError.invalidResponse
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
    private let supportedRadiusPresets: [HotspotWidgetRadiusPreset]

    /// 핫스팟 위젯 스냅샷 동기화 서비스를 생성합니다.
    /// - Parameters:
    ///   - summaryService: 서버 요약 RPC 호출 서비스입니다.
    ///   - snapshotStore: 앱 그룹 기반 핫스팟 스냅샷 저장소입니다.
    ///   - userSessionStore: 현재 로그인 사용자 컨텍스트 조회 저장소입니다.
    ///   - preferenceStore: 마지막 동기화 메타데이터를 저장할 기본 설정 저장소입니다.
    ///   - syncTTL: RPC 재조회 최소 간격(초)입니다.
    ///   - staleGraceInterval: 오프라인 캐시를 허용할 최대 유예 시간(초)입니다.
    ///   - supportedRadiusPresets: 서버 요약을 미리 동기화할 반경 preset 목록입니다.
    init(
        summaryService: HotspotWidgetSummaryServiceProtocol = HotspotWidgetSummaryService(),
        snapshotStore: HotspotWidgetSnapshotStoring = DefaultHotspotWidgetSnapshotStore.shared,
        userSessionStore: UserSessionStoreProtocol = DefaultUserSessionStore.shared,
        preferenceStore: UserDefaults = .standard,
        syncTTL: TimeInterval = 10 * 60,
        staleGraceInterval: TimeInterval = 3 * 60 * 60,
        supportedRadiusPresets: [HotspotWidgetRadiusPreset] = HotspotWidgetRadiusPreset.allCases
    ) {
        self.summaryService = summaryService
        self.snapshotStore = snapshotStore
        self.userSessionStore = userSessionStore
        self.preferenceStore = preferenceStore
        self.syncTTL = syncTTL
        self.staleGraceInterval = staleGraceInterval
        self.supportedRadiusPresets = supportedRadiusPresets
    }

    /// 서버 요약을 조회해 핫스팟 위젯 공유 스냅샷을 갱신합니다.
    /// - Parameters:
    ///   - force: `true`면 TTL을 무시하고 즉시 갱신합니다.
    ///   - now: TTL/상태 계산 기준 시각입니다.
    func sync(force: Bool, now: Date) async {
        let presetsToSync = supportedRadiusPresets.filter { shouldSync(force: force, now: now, radiusPreset: $0) }
        guard presetsToSync.isEmpty == false else { return }

        guard let user = userSessionStore.currentUserInfo(),
              user.id.isEmpty == false else {
            presetsToSync.forEach { saveGuestSnapshot(radiusPreset: $0, now: now) }
            return
        }

        for radiusPreset in presetsToSync {
            do {
                let summary = try await summaryService.fetchSummary(radiusKm: radiusPreset.radiusKm, now: now)
                saveMemberSnapshot(summary: summary, radiusPreset: radiusPreset, now: now)
            } catch {
                saveFailureSnapshot(radiusPreset: radiusPreset, now: now)
            }
        }
    }

    /// TTL과 이전 상태를 기준으로 이번 동기화를 수행할지 판단합니다.
    /// - Parameters:
    ///   - force: `true`면 즉시 동기화합니다.
    ///   - now: 판단 기준 시각입니다.
    /// - Returns: 동기화가 필요하면 `true`, 스킵 가능하면 `false`입니다.
    private func shouldSync(force: Bool, now: Date, radiusPreset: HotspotWidgetRadiusPreset) -> Bool {
        if force { return true }
        let snapshot = snapshotStore.load(radiusPreset: radiusPreset)
        let age = now.timeIntervalSince1970 - snapshot.updatedAt
        return age >= syncTTL
    }

    /// 비회원 상태 스냅샷을 저장합니다.
    /// - Parameters:
    ///   - radiusPreset: 현재 저장할 위젯 반경 preset입니다.
    ///   - now: 저장 시각입니다.
    private func saveGuestSnapshot(radiusPreset: HotspotWidgetRadiusPreset, now: Date) {
        save(
            HotspotWidgetSnapshot(
                radiusPreset: radiusPreset,
                status: .guestLocked,
                message: "로그인 후 주변 익명 핫스팟 트렌드를 위젯에서 확인할 수 있어요.",
                summary: nil,
                updatedAt: now.timeIntervalSince1970
            ),
            radiusPreset: radiusPreset,
            now: now
        )
    }

    /// 서버 요약 응답을 회원 상태 스냅샷으로 저장합니다.
    /// - Parameters:
    ///   - summary: 서버에서 조회한 최신 익명 핫스팟 요약 DTO입니다.
    ///   - radiusPreset: 스냅샷을 저장할 위젯 반경 preset입니다.
    ///   - now: 저장 시각입니다.
    private func saveMemberSnapshot(
        summary: HotspotWidgetSummaryDTO,
        radiusPreset: HotspotWidgetRadiusPreset,
        now: Date
    ) {
        let status = resolveMemberStatus(summary)
        let message = messageForMemberSummary(summary, status: status)
        let snapshot = HotspotWidgetSnapshot(
            radiusPreset: radiusPreset,
            status: status,
            message: message,
            summary: HotspotWidgetSummarySnapshot(
                radiusPreset: radiusPreset,
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
        save(snapshot, radiusPreset: radiusPreset, now: now)
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
    /// - Parameters:
    ///   - radiusPreset: 현재 저장할 위젯 반경 preset입니다.
    ///   - now: 저장 시각입니다.
    private func saveFailureSnapshot(radiusPreset: HotspotWidgetRadiusPreset, now: Date) {
        let current = snapshotStore.load(radiusPreset: radiusPreset)
        guard let cachedSummary = current.summary else {
            save(
                HotspotWidgetSnapshot(
                    radiusPreset: radiusPreset,
                    status: .syncDelayed,
                    message: "동기화가 지연되고 있어요. 앱을 열어 최신화해주세요.",
                    summary: nil,
                    updatedAt: now.timeIntervalSince1970
                ),
                radiusPreset: radiusPreset,
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
                radiusPreset: radiusPreset,
                status: status,
                message: message,
                summary: cachedSummary,
                updatedAt: now.timeIntervalSince1970
            ),
            radiusPreset: radiusPreset,
            now: now
        )
    }

    /// 위젯 스냅샷 저장 후 재로딩을 요청하고 마지막 동기화 시각을 기록합니다.
    /// - Parameters:
    ///   - snapshot: 저장할 핫스팟 위젯 스냅샷입니다.
    ///   - radiusPreset: 스냅샷을 저장할 위젯 반경 preset입니다.
    ///   - now: 마지막 동기화 시각 기록 기준입니다.
    private func save(
        _ snapshot: HotspotWidgetSnapshot,
        radiusPreset: HotspotWidgetRadiusPreset,
        now: Date
    ) {
        snapshotStore.save(snapshot, radiusPreset: radiusPreset)
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
                    catalogName: "기본 비교 구역",
                    sortOrder: 0,
                    references: legacyItems
                )
            ]
        )
    }
}
