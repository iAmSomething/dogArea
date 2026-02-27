import Foundation

struct PresenceRecord {
    let geohash7: String
    let lastSeenAt: TimeInterval
}

struct NearbyPrivacyPolicy {
    var minSampleSize: Int = 20
    var percentileFallback: Double = 0.8
    var daytimeDelayMinutes: Int = 30
    var nighttimeDelayMinutes: Int = 60
    var activeWindowMinutes: Int = 10
    var nightStartHour: Int = 22
    var nightEndHour: Int = 6
}

struct HotspotResult {
    let geohash7: String
    let countPublic: Int
    let sampleCount: Int
    let intensity: Double
    let privacyMode: String
    let suppressionReason: String?
}

func effectiveDelayMinutes(hour: Int, policy: NearbyPrivacyPolicy) -> Int {
    let isNight: Bool
    if policy.nightStartHour == policy.nightEndHour {
        isNight = false
    } else if policy.nightStartHour < policy.nightEndHour {
        isNight = hour >= policy.nightStartHour && hour < policy.nightEndHour
    } else {
        isNight = hour >= policy.nightStartHour || hour < policy.nightEndHour
    }
    return isNight ? policy.nighttimeDelayMinutes : policy.daytimeDelayMinutes
}

func percentileRank(index: Int, total: Int) -> Double {
    guard total > 1 else { return 1.0 }
    return Double(index) / Double(total - 1)
}

func aggregateHotspots(
    records: [PresenceRecord],
    now: TimeInterval,
    hour: Int,
    sensitiveGeohashes: Set<String>,
    policy: NearbyPrivacyPolicy = .init()
) -> [HotspotResult] {
    let delay = effectiveDelayMinutes(hour: hour, policy: policy)
    let windowStart = now - Double(delay + policy.activeWindowMinutes) * 60.0
    let windowEnd = now - Double(delay) * 60.0

    var grouped: [String: Int] = [:]
    for record in records {
        if record.lastSeenAt >= windowStart && record.lastSeenAt <= windowEnd {
            grouped[record.geohash7, default: 0] += 1
        }
    }

    let ranked = grouped
        .map { (geohash: $0.key, sampleCount: $0.value) }
        .sorted {
            if $0.sampleCount == $1.sampleCount {
                return $0.geohash < $1.geohash
            }
            return $0.sampleCount < $1.sampleCount
        }

    struct Candidate {
        let geohash: String
        let sampleCount: Int
        let percentile: Double
        let suppressionReason: String?
    }

    let candidates: [Candidate] = ranked.enumerated().compactMap { index, item in
        let percentile = percentileRank(index: index, total: ranked.count)
        let reason: String?
        if sensitiveGeohashes.contains(item.geohash) {
            reason = "sensitive_mask"
        } else if item.sampleCount < policy.minSampleSize {
            reason = "k_anon"
        } else {
            reason = nil
        }

        if reason == "sensitive_mask" {
            return nil
        }
        if reason == "k_anon" && percentile < policy.percentileFallback {
            return nil
        }
        return Candidate(
            geohash: item.geohash,
            sampleCount: item.sampleCount,
            percentile: percentile,
            suppressionReason: reason
        )
    }

    let maxVisibleCount = candidates
        .filter { $0.suppressionReason == nil }
        .map(\.sampleCount)
        .max() ?? 0

    let sortedByIntensity = candidates
        .map { candidate -> HotspotResult in
            let intensity: Double
            if candidate.suppressionReason == "k_anon" {
                intensity = max(0.05, min(1.0, candidate.percentile))
            } else if maxVisibleCount > 0 {
                intensity = min(1.0, max(0.0, Double(candidate.sampleCount) / Double(maxVisibleCount)))
            } else {
                intensity = 0.0
            }
            return HotspotResult(
                geohash7: candidate.geohash,
                countPublic: candidate.suppressionReason == nil ? candidate.sampleCount : 0,
                sampleCount: candidate.sampleCount,
                intensity: intensity,
                privacyMode: candidate.suppressionReason == "k_anon" ? "percentile_only" : "full",
                suppressionReason: candidate.suppressionReason
            )
        }
        .sorted {
            if $0.intensity == $1.intensity {
                return $0.geohash7 < $1.geohash7
            }
            return $0.intensity > $1.intensity
        }

    return sortedByIntensity
}

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let now = 1_770_000_000.0
let policy = NearbyPrivacyPolicy()

assertTrue(effectiveDelayMinutes(hour: 11, policy: policy) == 30, "daytime delay should be 30 minutes")
assertTrue(effectiveDelayMinutes(hour: 23, policy: policy) == 60, "nighttime delay should be 60 minutes")
assertTrue(effectiveDelayMinutes(hour: 3, policy: policy) == 60, "overnight delay should be 60 minutes")

let dayWindowRecords = [
    PresenceRecord(geohash7: "day-a", lastSeenAt: now - 35 * 60),
    PresenceRecord(geohash7: "day-a", lastSeenAt: now - 31 * 60),
    PresenceRecord(geohash7: "day-a", lastSeenAt: now - 25 * 60), // too recent for delayed window
]
let dayResult = aggregateHotspots(records: dayWindowRecords, now: now, hour: 11, sensitiveGeohashes: [])
assertTrue(dayResult.first?.sampleCount == 2, "day delayed window should include only 30~40 minute records")

let nightWindowRecords = [
    PresenceRecord(geohash7: "night-a", lastSeenAt: now - 65 * 60),
    PresenceRecord(geohash7: "night-a", lastSeenAt: now - 59 * 60), // too recent for night delayed window
]
let nightResult = aggregateHotspots(records: nightWindowRecords, now: now, hour: 23, sensitiveGeohashes: [])
assertTrue(nightResult.first?.sampleCount == 1, "night delayed window should include only 60~70 minute records")

var sparseRecords: [PresenceRecord] = []
for _ in 0..<5 { sparseRecords.append(.init(geohash7: "cell-low", lastSeenAt: now - 33 * 60)) }
for _ in 0..<10 { sparseRecords.append(.init(geohash7: "cell-mid", lastSeenAt: now - 33 * 60)) }
for _ in 0..<15 { sparseRecords.append(.init(geohash7: "cell-high", lastSeenAt: now - 33 * 60)) }

let sparseResult = aggregateHotspots(records: sparseRecords, now: now, hour: 11, sensitiveGeohashes: [])
assertTrue(sparseResult.count == 1, "k-anon fallback should keep only top-percentile sparse cell")
assertTrue(sparseResult[0].geohash7 == "cell-high", "highest sparse percentile cell should remain")
assertTrue(sparseResult[0].countPublic == 0, "sparse cell should hide exact count")
assertTrue(sparseResult[0].privacyMode == "percentile_only", "sparse cell should be percentile-only mode")
assertTrue(sparseResult[0].suppressionReason == "k_anon", "sparse cell should be marked as k-anon suppressed")

let maskedResult = aggregateHotspots(records: sparseRecords, now: now, hour: 11, sensitiveGeohashes: ["cell-high"])
assertTrue(maskedResult.isEmpty, "sensitive mask should remove matching hotspot from output")

print("PASS: nearby hotspot unit checks")
