import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

let mapView = load("dogArea/Views/MapView/MapView.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")

assertTrue(
    mapViewModel.contains("private let returnToOriginMinimumElapsed: TimeInterval = 480.0"),
    "MapViewModel should enforce minimum elapsed time before return suggestion"
)
assertTrue(
    mapViewModel.contains("private let returnToOriginExcursionDistanceThreshold: CLLocationDistance = 120.0"),
    "MapViewModel should require excursion history before return suggestion"
)
assertTrue(
    mapViewModel.contains("private let returnToOriginEntryRadius: CLLocationDistance = 25.0"),
    "MapViewModel should require re-entry radius for return suggestion"
)
assertTrue(
    mapViewModel.contains("private let returnToOriginDwellDuration: TimeInterval = 20.0"),
    "MapViewModel should require dwell duration before return suggestion"
)
assertTrue(
    mapViewModel.contains("private let returnToOriginCooldownDuration: TimeInterval = 600.0"),
    "MapViewModel should apply cooldown after continue action"
)
assertTrue(
    mapViewModel.contains("func evaluateReturnToOriginSuggestionIfNeeded(with location: CLLocation, now: Date)"),
    "MapViewModel should evaluate return-to-origin policy from location updates"
)
assertTrue(
    mapViewModel.contains("func continueWalkAfterReturnToOriginSuggestion()"),
    "MapViewModel should expose continue action for return suggestion"
)
assertTrue(
    mapViewModel.contains("func endWalkAfterReturnToOriginSuggestion()"),
    "MapViewModel should expose end action for return suggestion"
)
assertTrue(
    mapViewModel.contains("self.evaluateReturnToOriginSuggestionIfNeeded(with: location, now: Date())"),
    "MapViewModel should evaluate return suggestion in didUpdateLocations"
)

assertTrue(
    mapView.contains("case .returnToOrigin"),
    "MapView top banner kind should include return-to-origin suggestion"
)
assertTrue(
    mapView.contains("viewModel.continueWalkAfterReturnToOriginSuggestion()"),
    "MapView return-to-origin banner should bind continue action"
)
assertTrue(
    mapView.contains("viewModel.endWalkAfterReturnToOriginSuggestion()"),
    "MapView return-to-origin banner should bind end action"
)
assertTrue(
    mapView.contains("if viewModel.isWalking && viewModel.hasReturnToOriginSuggestion"),
    "MapView banner queue should prioritize return-to-origin suggestion while walking"
)

print("PASS: walk return-to-origin suggestion unit checks")
