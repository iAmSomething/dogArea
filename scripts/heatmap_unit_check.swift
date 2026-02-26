import Foundation

struct WalkPoint {
    let latitude: Double
    let longitude: Double
    let recordedAt: TimeInterval
}

struct HeatmapCell: Equatable {
    let geohash: String
    let score: Double
}

enum HeatmapTestEngine {
    private static let halfLifeDays = 21.0
    private static let lambda = log(2.0) / halfLifeDays

    static func decayWeight(recordedAt: TimeInterval, now: Date) -> Double {
        let ageDays = max(0.0, (now.timeIntervalSince1970 - recordedAt) / 86_400.0)
        return exp(-lambda * ageDays)
    }

    static func aggregate(points: [WalkPoint], now: Date) -> [HeatmapCell] {
        var bucket: [String: Double] = [:]
        for point in points {
            let geohash = Geohash.encode(
                latitude: point.latitude,
                longitude: point.longitude,
                precision: 7
            )
            bucket[geohash, default: 0.0] += decayWeight(recordedAt: point.recordedAt, now: now)
        }
        guard let maxWeight = bucket.values.max(), maxWeight > 0 else {
            return []
        }
        return bucket.keys.sorted().compactMap { key in
            guard let value = bucket[key] else { return nil }
            return HeatmapCell(geohash: key, score: max(0.0, min(1.0, value / maxWeight)))
        }
    }
}

enum Geohash {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")
    private static let bitMasks = [16, 8, 4, 2, 1]

    static func encode(latitude: Double, longitude: Double, precision: Int) -> String {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var isEvenBit = true
        var bitIndex = 0
        var currentChar = 0
        var output = ""

        while output.count < max(1, precision) {
            if isEvenBit {
                let mid = (lonRange.0 + lonRange.1) / 2.0
                if longitude >= mid {
                    currentChar |= bitMasks[bitIndex]
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2.0
                if latitude >= mid {
                    currentChar |= bitMasks[bitIndex]
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }
            isEvenBit.toggle()
            if bitIndex < 4 {
                bitIndex += 1
            } else {
                output.append(base32[currentChar])
                bitIndex = 0
                currentChar = 0
            }
        }
        return output
    }
}

@inline(__always)
func assertNear(_ value: Double, _ expected: Double, tolerance: Double, _ message: String) {
    if abs(value - expected) > tolerance {
        fputs("FAIL: \(message) expected \(expected), got \(value)\n", stderr)
        exit(1)
    }
}

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let now = Date(timeIntervalSince1970: 1_770_000_000)

let day0 = HeatmapTestEngine.decayWeight(recordedAt: now.timeIntervalSince1970, now: now)
let day7 = HeatmapTestEngine.decayWeight(recordedAt: now.timeIntervalSince1970 - 7 * 86_400, now: now)
let day21 = HeatmapTestEngine.decayWeight(recordedAt: now.timeIntervalSince1970 - 21 * 86_400, now: now)
let day60 = HeatmapTestEngine.decayWeight(recordedAt: now.timeIntervalSince1970 - 60 * 86_400, now: now)

assertNear(day0, 1.0, tolerance: 0.0001, "decay day0")
assertNear(day21, 0.5, tolerance: 0.01, "decay day21")
assertTrue(day0 > day7 && day7 > day21 && day21 > day60, "decay monotonic")
assertNear(day60, 0.138, tolerance: 0.02, "decay day60")

let points = [
    WalkPoint(latitude: 37.5665, longitude: 126.9780, recordedAt: now.timeIntervalSince1970),
    WalkPoint(latitude: 37.56651, longitude: 126.97801, recordedAt: now.timeIntervalSince1970 - 3 * 86_400),
    WalkPoint(latitude: 37.5650, longitude: 126.9770, recordedAt: now.timeIntervalSince1970 - 40 * 86_400)
]

let first = HeatmapTestEngine.aggregate(points: points, now: now)
let second = HeatmapTestEngine.aggregate(points: points.shuffled(), now: now)

assertTrue(!first.isEmpty, "heatmap aggregate should not be empty")
assertTrue(first == second, "deterministic aggregate for same input set")
assertTrue(first.allSatisfy { (0.0...1.0).contains($0.score) }, "normalized score range")
assertNear(first.map(\.score).max() ?? 0.0, 1.0, tolerance: 0.0001, "max normalized score")

print("PASS: heatmap unit checks")
