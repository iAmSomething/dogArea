import Foundation
import CryptoKit

struct FlagState {
    let enabled: Bool
    let rolloutPercent: Int
}

func rolloutBucket(appInstanceId: String, key: String) -> Int {
    let seed = "\(appInstanceId):\(key)"
    let digest = SHA256.hash(data: Data(seed.utf8))
    guard let first = Array(digest).first else { return 0 }
    return Int(first) % 100
}

func isEnabled(_ state: FlagState, appInstanceId: String, key: String) -> Bool {
    guard state.enabled else { return false }
    let percent = max(0, min(100, state.rolloutPercent))
    if percent >= 100 { return true }
    if percent <= 0 { return false }
    return rolloutBucket(appInstanceId: appInstanceId, key: key) < percent
}

struct KPIInput {
    let walkSuccess: Double
    let walkFailed: Double
    let watchProcessed: Double
    let watchApplied: Double
    let caricatureSuccess: Double
    let caricatureFailed: Double
    let nearbyOptInUsers: Double
    let nearbyOptInTouchedUsers: Double
}

func kpiRates(_ input: KPIInput) -> (walk: Double?, watchLoss: Double?, caricature: Double?, nearby: Double?) {
    let walkDenominator = input.walkSuccess + input.walkFailed
    let walkRate = walkDenominator == 0 ? nil : input.walkSuccess / walkDenominator

    let watchLossRate = input.watchProcessed == 0
    ? nil
    : 1 - (input.watchApplied / input.watchProcessed)

    let caricatureDenominator = input.caricatureSuccess + input.caricatureFailed
    let caricatureRate = caricatureDenominator == 0 ? nil : input.caricatureSuccess / caricatureDenominator

    let nearbyRate = input.nearbyOptInTouchedUsers == 0
    ? nil
    : input.nearbyOptInUsers / input.nearbyOptInTouchedUsers

    return (walkRate, watchLossRate, caricatureRate, nearbyRate)
}

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let appId = "app-instance-a"
let key = "ff_heatmap_v1"
let bucket = rolloutBucket(appInstanceId: appId, key: key)
assertTrue(bucket >= 0 && bucket < 100, "bucket must be 0...99")
assertTrue(rolloutBucket(appInstanceId: appId, key: key) == bucket, "bucket must be deterministic")

assertTrue(isEnabled(.init(enabled: false, rolloutPercent: 100), appInstanceId: appId, key: key) == false, "disabled flag should be false")
assertTrue(isEnabled(.init(enabled: true, rolloutPercent: 0), appInstanceId: appId, key: key) == false, "0 percent rollout should be false")
assertTrue(isEnabled(.init(enabled: true, rolloutPercent: 100), appInstanceId: appId, key: key) == true, "100 percent rollout should be true")

let rates = kpiRates(.init(
    walkSuccess: 96,
    walkFailed: 4,
    watchProcessed: 100,
    watchApplied: 98,
    caricatureSuccess: 45,
    caricatureFailed: 5,
    nearbyOptInUsers: 40,
    nearbyOptInTouchedUsers: 100
))

assertTrue(abs((rates.walk ?? 0) - 0.96) < 0.0001, "walk success rate")
assertTrue(abs((rates.watchLoss ?? 0) - 0.02) < 0.0001, "watch loss rate")
assertTrue(abs((rates.caricature ?? 0) - 0.9) < 0.0001, "caricature success rate")
assertTrue(abs((rates.nearby ?? 0) - 0.4) < 0.0001, "nearby opt-in ratio")

print("PASS: feature flag rollout unit checks")
