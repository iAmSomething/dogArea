import Foundation

enum SyncOutboxStage: String, Codable, CaseIterable {
    case session
    case points
    case meta

    var order: Int {
        switch self {
        case .session: return 0
        case .points: return 1
        case .meta: return 2
        }
    }
}

enum SyncOutboxStatus: String, Codable {
    case queued
    case retrying
    case processing
    case permanentFailed
    case completed
}

enum SyncOutboxErrorCode: String, Codable {
    case offline = "offline"
    case tokenExpired = "token_expired"
    case unauthorized = "unauthorized"
    case serverError = "server_error"
    case conflict = "conflict"
    case schemaMismatch = "schema_mismatch"
    case storageQuota = "storage_quota"
    case notConfigured = "not_configured"
    case unknown = "unknown"
}

struct SyncOutboxItem: Codable, Identifiable, Equatable {
    let id: String
    let walkSessionId: String
    let stage: SyncOutboxStage
    let idempotencyKey: String
    let payload: [String: String]
    var status: SyncOutboxStatus
    var retryCount: Int
    var nextRetryAt: TimeInterval
    var lastErrorCode: SyncOutboxErrorCode?
    let createdAt: TimeInterval
    var updatedAt: TimeInterval
}

struct SyncOutboxSummary: Equatable {
    let pendingCount: Int
    let permanentFailureCount: Int
    let lastErrorCode: SyncOutboxErrorCode?
}

struct SyncBackfillValidationSummary: Codable, Equatable {
    let sessionCount: Int
    let pointCount: Int
    let totalAreaM2: Double
    let totalDurationSec: Double
}

enum SyncOutboxSendResult: Equatable {
    case success
    case retryable(SyncOutboxErrorCode)
    case permanent(SyncOutboxErrorCode)
}

protocol SyncOutboxTransporting {
    /// 대기 중인 동기화 항목 하나를 원격 전송합니다.
    /// - Parameter item: 전송할 outbox 항목입니다.
    /// - Returns: 전송 결과와 재시도 가능 여부입니다.
    func send(item: SyncOutboxItem) async -> SyncOutboxSendResult
}

final class SyncOutboxStore {
    static let shared = SyncOutboxStore()

    private let stateQueue = DispatchQueue(label: "com.th.dogArea.sync-outbox-store.state")
    private let storageKey = "sync.outbox.items.v1"
    private var items: [SyncOutboxItem] = []
    private let maxItems = 500

    private init() {
        load()
    }

    /// 산책 세션 DTO를 stage별 outbox 항목으로 분해해 큐에 적재합니다.
    /// - Parameter sessionDTO: 큐에 적재할 산책 세션 백필 DTO입니다.
    func enqueueWalkStages(sessionDTO: WalkSessionBackfillDTO) {
        let sessionId = sessionDTO.walkSessionId
        let baseKey = "walk-\(sessionId)"
        let now = Date().timeIntervalSince1970
        let basePayload: [String: String] = [
            "walk_session_id": sessionId,
            "user_id": sessionDTO.ownerUserId ?? "",
            "pet_id": sessionDTO.petId ?? "",
            "created_at": String(sessionDTO.createdAt),
            "started_at": String(sessionDTO.startedAt),
            "ended_at": String(sessionDTO.endedAt),
            "source_device": sessionDTO.sourceDevice
        ]

        let stagePayloads: [(SyncOutboxStage, [String: String])] = [
            (
                .session,
                basePayload.merging(
                    [
                        "duration_sec": String(sessionDTO.durationSec),
                        "area_m2": String(sessionDTO.areaM2),
                    ],
                    uniquingKeysWith: { _, latest in latest }
                )
            ),
            (
                .points,
                basePayload.merging(
                    [
                        "point_count": String(sessionDTO.pointCount),
                        "points_json": sessionDTO.pointsJSONString,
                        "route_point_count": String(sessionDTO.routePoints.count),
                        "mark_point_count": String(sessionDTO.markPoints.count),
                        "route_points_json": sessionDTO.routePointsJSONString,
                        "mark_points_json": sessionDTO.markPointsJSONString
                    ],
                    uniquingKeysWith: { _, latest in latest }
                )
            ),
            (
                .meta,
                basePayload.merging(
                    [
                        "has_image": sessionDTO.hasImage ? "true" : "false",
                        "map_image_url": sessionDTO.mapImageURL ?? ""
                    ],
                    uniquingKeysWith: { _, latest in latest }
                )
            ),
        ]

        stateQueue.sync {
            var mutableItems = items
            var enqueuedCount = 0
            stagePayloads.forEach { stage, payload in
                let idempotencyKey = "\(baseKey)-\(stage.rawValue)"
                let exists = mutableItems.contains(where: { $0.idempotencyKey == idempotencyKey })
                guard exists == false else { return }
                mutableItems.append(
                    SyncOutboxItem(
                        id: UUID().uuidString.lowercased(),
                        walkSessionId: sessionId,
                        stage: stage,
                        idempotencyKey: idempotencyKey,
                        payload: payload,
                        status: .queued,
                        retryCount: 0,
                        nextRetryAt: now,
                        lastErrorCode: nil,
                        createdAt: now,
                        updatedAt: now
                    )
                )
                enqueuedCount += 1
            }
            if mutableItems.count > maxItems {
                let overflow = mutableItems.count - maxItems
                let removable = mutableItems
                    .enumerated()
                    .filter { _, item in item.status == .completed || item.status == .permanentFailed }
                    .prefix(overflow)
                    .map(\.offset)
                removable.reversed().forEach { mutableItems.remove(at: $0) }
            }
            items = mutableItems
            persistLocked()
            #if DEBUG
            if enqueuedCount > 0 {
                print("[SyncOutbox] enqueue session=\(sessionId) stages=\(enqueuedCount) total=\(mutableItems.count)")
            }
            #endif
        }
    }

    /// 현재 outbox 누적 상태를 요약합니다.
    /// - Returns: pending/permanent failure 수와 마지막 오류 코드를 담은 요약 값입니다.
    func summary() -> SyncOutboxSummary {
        stateQueue.sync {
            let pending = items.filter { $0.status == .queued || $0.status == .retrying || $0.status == .processing }.count
            let permanent = items.filter { $0.status == .permanentFailed }.count
            let lastError = items.reversed().compactMap(\.lastErrorCode).first
            return SyncOutboxSummary(pendingCount: pending, permanentFailureCount: permanent, lastErrorCode: lastError)
        }
    }

    /// 큐에 적재된 outbox 항목을 전송 순서대로 flush합니다.
    /// - Parameters:
    ///   - transport: 실제 전송을 수행할 transport 구현체입니다.
    ///   - now: 재시도 가능 시점을 계산할 기준 시각입니다.
    /// - Returns: flush 직후의 outbox 상태 요약입니다.
    @discardableResult
    func flush(using transport: SyncOutboxTransporting, now: Date = Date()) async -> SyncOutboxSummary {
        let nowTs = now.timeIntervalSince1970
        #if DEBUG
        print("[SyncOutbox] flush start now=\(nowTs)")
        #endif
        while let next = nextDispatchableItem(now: nowTs) {
            #if DEBUG
            print("[SyncOutbox] dispatch stage=\(next.stage.rawValue) session=\(next.walkSessionId) retry=\(next.retryCount)")
            #endif
            updateItem(id: next.id) { item in
                item.status = .processing
                item.updatedAt = Date().timeIntervalSince1970
            }

            let result = await transport.send(item: next)
            let currentNow = Date().timeIntervalSince1970
            switch result {
            case .success:
                #if DEBUG
                print("[SyncOutbox] success stage=\(next.stage.rawValue) session=\(next.walkSessionId)")
                #endif
                updateItem(id: next.id) { item in
                    item.status = .completed
                    item.lastErrorCode = nil
                    item.updatedAt = currentNow
                }
            case .retryable(let code):
                #if DEBUG
                print("[SyncOutbox] retryable stage=\(next.stage.rawValue) session=\(next.walkSessionId) code=\(code.rawValue)")
                #endif
                let delay = Self.retryDelay(retryCount: next.retryCount + 1)
                updateItem(id: next.id) { item in
                    item.status = .retrying
                    item.retryCount += 1
                    item.lastErrorCode = code
                    item.nextRetryAt = currentNow + delay
                    item.updatedAt = currentNow
                }
                return summary()
            case .permanent(let code):
                #if DEBUG
                print("[SyncOutbox] permanent-failed stage=\(next.stage.rawValue) session=\(next.walkSessionId) code=\(code.rawValue)")
                #endif
                updateItem(id: next.id) { item in
                    item.status = .permanentFailed
                    item.lastErrorCode = code
                    item.updatedAt = currentNow
                }
                if code == .notConfigured {
                    continue
                }
                markPendingStagesPermanent(
                    walkSessionId: next.walkSessionId,
                    excludingItemId: next.id,
                    code: code,
                    now: currentNow
                )
                continue
            }
        }
        return summary()
    }

    /// 영구 실패 항목을 다시 retrying 상태로 되돌립니다.
    /// - Parameter walkSessionIds: 재큐잉할 산책 세션 식별자 집합입니다. `nil`이면 전체 영구 실패 항목을 대상으로 합니다.
    func requeuePermanentFailures(walkSessionIds: Set<String>? = nil) {
        stateQueue.sync {
            let now = Date().timeIntervalSince1970
            for index in items.indices {
                guard items[index].status == .permanentFailed else { continue }
                if let walkSessionIds, walkSessionIds.contains(items[index].walkSessionId) == false {
                    continue
                }
                items[index].status = .retrying
                items[index].retryCount = 0
                items[index].nextRetryAt = now
                items[index].lastErrorCode = nil
                items[index].updatedAt = now
            }
            persistLocked()
        }
    }

    /// 재시도 횟수에 따른 지수 백오프 지연 시간을 계산합니다.
    /// - Parameter retryCount: 현재까지 누적된 재시도 횟수입니다.
    /// - Returns: 다음 재시도까지 대기할 초 단위 시간입니다.
    private static func retryDelay(retryCount: Int) -> TimeInterval {
        let exp = pow(2.0, Double(max(0, retryCount)))
        return min(900.0, 5.0 * exp)
    }

    /// 현재 시각 기준으로 바로 전송 가능한 다음 outbox 항목을 선택합니다.
    /// - Parameter now: 전송 가능 시각 비교에 사용할 현재 epoch 값입니다.
    /// - Returns: 지금 전송 가능한 첫 번째 outbox 항목입니다. 없으면 `nil`입니다.
    private func nextDispatchableItem(now: TimeInterval) -> SyncOutboxItem? {
        stateQueue.sync {
            return items
                .sorted { lhs, rhs in
                    if lhs.createdAt == rhs.createdAt {
                        if lhs.stage.order == rhs.stage.order {
                            return lhs.id < rhs.id
                        }
                        return lhs.stage.order < rhs.stage.order
                    }
                    return lhs.createdAt < rhs.createdAt
                }
                .first(where: {
                    ($0.status == .queued || $0.status == .retrying || $0.status == .processing) &&
                    $0.nextRetryAt <= now
                })
        }
    }

    /// 특정 outbox 항목을 수정하고 변경 내용을 영속화합니다.
    /// - Parameters:
    ///   - id: 수정할 outbox 항목 식별자입니다.
    ///   - block: 항목을 제자리 수정하는 클로저입니다.
    private func updateItem(id: String, _ block: (inout SyncOutboxItem) -> Void) {
        stateQueue.sync {
            if let idx = items.firstIndex(where: { $0.id == id }) {
                block(&items[idx])
                persistLocked()
            }
        }
    }

    /// 동일 세션의 후속 pending stage를 영구 실패로 격리해 다른 정상 세션 flush를 계속 진행합니다.
    /// - Parameters:
    ///   - walkSessionId: 영구 실패가 확정된 산책 세션 식별자입니다.
    ///   - excludingItemId: 이미 실패 처리한 현재 stage 항목 식별자입니다.
    ///   - code: 후속 stage에 동일하게 기록할 영구 오류 코드입니다.
    ///   - now: 상태 갱신 시각(epoch seconds)입니다.
    private func markPendingStagesPermanent(
        walkSessionId: String,
        excludingItemId: String,
        code: SyncOutboxErrorCode,
        now: TimeInterval
    ) {
        stateQueue.sync {
            var mutated = false
            for index in items.indices {
                guard items[index].walkSessionId == walkSessionId else { continue }
                guard items[index].id != excludingItemId else { continue }
                guard Self.isPendingStatus(items[index].status) else { continue }
                items[index].status = .permanentFailed
                items[index].lastErrorCode = code
                items[index].updatedAt = now
                mutated = true
            }
            if mutated {
                persistLocked()
            }
        }
    }

    /// pending 상태로 간주할 outbox 상태인지 판정합니다.
    /// - Parameter status: 판정할 outbox 상태입니다.
    /// - Returns: 추가 전송 또는 격리 대상이면 `true`, 그 외에는 `false`입니다.
    private static func isPendingStatus(_ status: SyncOutboxStatus) -> Bool {
        switch status {
        case .queued, .retrying, .processing:
            return true
        case .permanentFailed, .completed:
            return false
        }
    }

    /// 로컬 저장소에서 outbox 항목 배열을 복원합니다.
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SyncOutboxItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    /// 현재 outbox 항목 배열을 로컬 저장소에 기록합니다.
    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
