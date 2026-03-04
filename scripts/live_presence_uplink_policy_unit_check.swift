import Foundation

func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

let mapViewModelPath = URL(fileURLWithPath: "dogArea/Views/MapView/MapViewModel.swift")
let mapViewModel = try String(contentsOf: mapViewModelPath, encoding: .utf8)

assertTrue(mapViewModel.contains("enum PresenceHeartbeatState"), "MapViewModel should define presence heartbeat states")
assertTrue(mapViewModel.contains("livePresenceUploadBaseInterval: TimeInterval = 10.0"), "Live presence base interval should be 10 seconds")
assertTrue(mapViewModel.contains("livePresenceUploadMinDistance: CLLocationDistance = 15.0"), "Live presence distance threshold should be 15m")
assertTrue(mapViewModel.contains("resolvedLivePresenceUploadInterval()"), "MapViewModel should resolve adaptive upload interval")
assertTrue(mapViewModel.contains("ProcessInfo.processInfo.isLowPowerModeEnabled"), "Low power adaptive policy should be applied")
assertTrue(mapViewModel.contains("UIApplication.shared.applicationState != .active"), "Background adaptive policy should be applied")
assertTrue(mapViewModel.contains("flushLivePresenceOutboxIfNeeded()"), "Live presence should flush queued items")
assertTrue(mapViewModel.contains("\"\\(sessionId)-\\(livePresenceSequence)\""), "Idempotency key should use sessionId+sequence")
assertTrue(mapViewModel.contains("livePresenceOutbox"), "Live presence outbox should be maintained")

print("PASS: live presence uplink policy unit checks")
