import Foundation

struct PresenceRecord {
    let geohash7: String
    let lastSeenAt: TimeInterval
}

final class NearbyScheduler {
    var locationSharingEnabled = false
    var nearbyHotspotEnabled = true
    var isWalking = false
    private(set) var sentCount = 0
    private(set) var fetchedCount = 0
    private var lastSentAt: TimeInterval = 0
    private var lastFetchedAt: TimeInterval = 0

    func tick(now: TimeInterval) {
        if locationSharingEnabled && isWalking && now - lastSentAt >= 30 {
            lastSentAt = now
            sentCount += 1
        }
        if nearbyHotspotEnabled && now - lastFetchedAt >= 10 {
            lastFetchedAt = now
            fetchedCount += 1
        }
    }
}

func aggregateAlive(records: [PresenceRecord], now: TimeInterval) -> [String: Int] {
    var grouped: [String: Int] = [:]
    for record in records {
        if now - record.lastSeenAt <= 600 {
            grouped[record.geohash7, default: 0] += 1
        }
    }
    return grouped
}

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let scheduler = NearbyScheduler()
scheduler.tick(now: 10)
assertTrue(scheduler.sentCount == 0, "opt-out user must not send presence")
assertTrue(scheduler.fetchedCount == 1, "hotspot fetch runs every 10s baseline")

scheduler.locationSharingEnabled = true
scheduler.isWalking = true
scheduler.tick(now: 20)
assertTrue(scheduler.sentCount == 0, "30s interval not reached")
scheduler.tick(now: 31)
assertTrue(scheduler.sentCount == 1, "presence should send at 30s interval")
scheduler.tick(now: 59)
assertTrue(scheduler.sentCount == 1, "presence must not oversend before next interval")
scheduler.tick(now: 61)
assertTrue(scheduler.sentCount == 2, "presence sends again after another 30s")

let now = 1_770_000_000.0
let grouped = aggregateAlive(records: [
    .init(geohash7: "wydm3yr", lastSeenAt: now - 100),
    .init(geohash7: "wydm3yr", lastSeenAt: now - 500),
    .init(geohash7: "wydm3yx", lastSeenAt: now - 700),
    .init(geohash7: "wydm3yx", lastSeenAt: now - 601),
], now: now)

assertTrue(grouped["wydm3yr"] == 2, "alive records should be counted")
assertTrue(grouped["wydm3yx"] == nil, "ttl-expired records must be excluded")

print("PASS: nearby hotspot unit checks")
