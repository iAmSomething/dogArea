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
    case offline
    case tokenExpired = "token_expired"
    case schemaMismatch = "schema_mismatch"
}

struct SyncOutboxItem: Codable, Equatable {
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

enum SyncOutboxSendResult: Equatable {
    case success
    case retryable(SyncOutboxErrorCode)
    case permanent(SyncOutboxErrorCode)
}

protocol SyncOutboxTransporting {
    func send(item: SyncOutboxItem) async -> SyncOutboxSendResult
}

final class SyncOutboxStore {
    private var items: [SyncOutboxItem] = []

    func enqueueWalkStages(walkSessionId: UUID, hasImage: Bool) {
        let sessionId = walkSessionId.uuidString.lowercased()
        let baseKey = "walk-\(sessionId)"
        let now = Date().timeIntervalSince1970
        let basePayload = ["walk_session_id": sessionId]
        let stagePayloads: [(SyncOutboxStage, [String: String])] = [
            (.session, basePayload),
            (.points, basePayload.merging(["point_count": "4"], uniquingKeysWith: { _, latest in latest })),
            (.meta, basePayload.merging(["has_image": hasImage ? "true" : "false"], uniquingKeysWith: { _, latest in latest }))
        ]

        stagePayloads.forEach { stage, payload in
            let idempotencyKey = "\(baseKey)-\(stage.rawValue)"
            let exists = items.contains(where: { $0.idempotencyKey == idempotencyKey && $0.status != .completed })
            guard exists == false else { return }
            items.append(
                .init(
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
        }
    }

    func snapshot() -> [SyncOutboxItem] {
        items
    }

    func summary() -> SyncOutboxSummary {
        let pending = items.filter { $0.status == .queued || $0.status == .retrying || $0.status == .processing }.count
        let permanent = items.filter { $0.status == .permanentFailed }.count
        let lastError = items.reversed().compactMap(\.lastErrorCode).first
        return .init(pendingCount: pending, permanentFailureCount: permanent, lastErrorCode: lastError)
    }

    @discardableResult
    func flush(using transport: SyncOutboxTransporting, now: Date = Date()) async -> SyncOutboxSummary {
        let nowTs = now.timeIntervalSince1970
        while let next = nextDispatchableItem(now: nowTs) {
            update(next.id) {
                $0.status = .processing
            }

            let result = await transport.send(item: next)
            switch result {
            case .success:
                update(next.id) {
                    $0.status = .completed
                    $0.lastErrorCode = nil
                }
            case .retryable(let code):
                update(next.id) {
                    $0.status = .retrying
                    $0.retryCount += 1
                    $0.lastErrorCode = code
                    $0.nextRetryAt = Date().timeIntervalSince1970 + 5
                }
                return summary()
            case .permanent(let code):
                update(next.id) {
                    $0.status = .permanentFailed
                    $0.lastErrorCode = code
                }
                if code == .schemaMismatch {
                    markPendingStagesPermanent(
                        walkSessionId: next.walkSessionId,
                        excludingItemId: next.id,
                        code: code
                    )
                }
                continue
            }
        }
        return summary()
    }

    private func markPendingStagesPermanent(
        walkSessionId: String,
        excludingItemId: String,
        code: SyncOutboxErrorCode
    ) {
        for index in items.indices {
            guard items[index].walkSessionId == walkSessionId else { continue }
            guard items[index].id != excludingItemId else { continue }
            guard Self.isPendingStatus(items[index].status) else { continue }
            items[index].status = .permanentFailed
            items[index].lastErrorCode = code
            items[index].updatedAt = Date().timeIntervalSince1970
        }
    }

    private static func isPendingStatus(_ status: SyncOutboxStatus) -> Bool {
        switch status {
        case .queued, .retrying, .processing:
            return true
        case .permanentFailed, .completed:
            return false
        }
    }

    private func nextDispatchableItem(now: TimeInterval) -> SyncOutboxItem? {
        items.sorted {
            if $0.createdAt == $1.createdAt {
                if $0.stage.order == $1.stage.order {
                    return $0.id < $1.id
                }
                return $0.stage.order < $1.stage.order
            }
            return $0.createdAt < $1.createdAt
        }
        .first(where: {
            ($0.status == .queued || $0.status == .retrying || $0.status == .processing) &&
            $0.nextRetryAt <= now
        })
    }

    private func update(_ id: String, _ mutate: (inout SyncOutboxItem) -> Void) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[idx])
        items[idx].updatedAt = Date().timeIntervalSince1970
    }
}

final class RecordingTransport: SyncOutboxTransporting {
    private let scripted: [SyncOutboxSendResult]
    private var cursor: Int = 0
    private(set) var sentStages: [SyncOutboxStage] = []

    init(scripted: [SyncOutboxSendResult]) {
        self.scripted = scripted
    }

    func send(item: SyncOutboxItem) async -> SyncOutboxSendResult {
        sentStages.append(item.stage)
        defer { cursor += 1 }
        if cursor < scripted.count {
            return scripted[cursor]
        }
        return .success
    }
}

@inline(__always)
func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let session = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

let queueA = SyncOutboxStore()
queueA.enqueueWalkStages(walkSessionId: session, hasImage: false)
let snapshotA = queueA.snapshot()
assertTrue(snapshotA.count == 3, "must enqueue three stages")
assertTrue(snapshotA.map(\.stage) == [.session, .points, .meta], "stage order must be session->points->meta")
let metaItem = snapshotA.first(where: { $0.stage == .meta })
assertTrue(metaItem?.payload["has_image"] == "false", "meta payload must store has_image=false when image missing")

queueA.enqueueWalkStages(walkSessionId: session, hasImage: false)
assertTrue(queueA.snapshot().count == 3, "duplicate enqueue before completion must be ignored")

let queueB = SyncOutboxStore()
queueB.enqueueWalkStages(walkSessionId: session, hasImage: true)
let transportB = RecordingTransport(scripted: [.success, .retryable(.offline), .success])
let summaryB = await queueB.flush(using: transportB)
assertTrue(transportB.sentStages == [.session, .points], "flush must stop at first retryable failure")
assertTrue(summaryB.pendingCount == 2, "retryable stop should keep remaining items pending")
assertTrue(summaryB.permanentFailureCount == 0, "retryable stop should not create permanent failures")
assertTrue(summaryB.lastErrorCode == .offline, "retryable failure code must be retained")

let queueC = SyncOutboxStore()
queueC.enqueueWalkStages(walkSessionId: session, hasImage: true)
let secondSession = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
queueC.enqueueWalkStages(walkSessionId: secondSession, hasImage: false)
let transportC = RecordingTransport(scripted: [.permanent(.schemaMismatch), .success, .success, .success])
let summaryC = await queueC.flush(using: transportC)
assertTrue(transportC.sentStages == [.session, .session, .points, .meta], "permanent session failure should quarantine same-session stages and continue with next session")
assertTrue(summaryC.pendingCount == 0, "queue should drain once permanent session is isolated and later stages succeed")
assertTrue(summaryC.permanentFailureCount == 3, "failed session and its remaining stages should all be permanent")
assertTrue(summaryC.lastErrorCode == .schemaMismatch, "permanent failure code must be retained")

print("PASS: walk sync consistency outbox unit checks")
