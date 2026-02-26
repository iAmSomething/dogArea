import Foundation

struct WatchActionDTO: Equatable {
    let action: String
    let actionId: String
    let sentAt: TimeInterval
}

final class WatchDedupeStore {
    private let maxCount: Int
    private var order: [String] = []
    private var ids: Set<String> = []

    init(maxCount: Int = 500) {
        self.maxCount = maxCount
    }

    func shouldProcess(_ actionId: String) -> Bool {
        guard ids.contains(actionId) == false else { return false }
        ids.insert(actionId)
        order.append(actionId)
        if order.count > maxCount {
            let overflow = order.count - maxCount
            let removed = Array(order.prefix(overflow))
            order.removeFirst(overflow)
            removed.forEach { ids.remove($0) }
        }
        return true
    }
}

final class WatchQueueStore {
    private(set) var pending: [WatchActionDTO] = []

    func enqueue(_ action: WatchActionDTO) {
        pending.append(action)
    }

    func flush(isReachable: Bool) -> [WatchActionDTO] {
        guard isReachable else { return [] }
        let flushed = pending
        pending.removeAll()
        return flushed
    }
}

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let dedupe = WatchDedupeStore(maxCount: 3)
assertTrue(dedupe.shouldProcess("a1"), "first action should be processed")
assertTrue(dedupe.shouldProcess("a1") == false, "duplicate action must be ignored")
assertTrue(dedupe.shouldProcess("a2"), "new action should be processed")
assertTrue(dedupe.shouldProcess("a3"), "new action should be processed")
assertTrue(dedupe.shouldProcess("a4"), "new action should be processed")
assertTrue(dedupe.shouldProcess("a1"), "evicted old id should be processable again")

let queue = WatchQueueStore()
queue.enqueue(.init(action: "addPoint", actionId: "q1", sentAt: 1))
queue.enqueue(.init(action: "addPoint", actionId: "q2", sentAt: 2))
assertTrue(queue.pending.count == 2, "queue should store offline actions")

let offlineFlush = queue.flush(isReachable: false)
assertTrue(offlineFlush.isEmpty, "offline flush should not send actions")
assertTrue(queue.pending.count == 2, "offline flush should keep queue")

let onlineFlush = queue.flush(isReachable: true)
assertTrue(onlineFlush.count == 2, "online flush should send all queued actions")
assertTrue(queue.pending.isEmpty, "queue should be empty after successful flush")

print("PASS: watch reliability unit checks")
