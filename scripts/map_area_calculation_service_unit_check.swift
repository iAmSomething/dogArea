import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if condition == false {
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

let service = load("dogArea/Views/MapView/MapAreaCalculationService.swift")
let mapViewModel = load("dogArea/Views/MapView/MapViewModel.swift")

assertTrue(service.contains("protocol MapAreaCalculationServicing"), "MapAreaCalculationServicing protocol should exist")
assertTrue(service.contains("func calculateArea(points: [Location]) -> Double"), "service should expose calculateArea API")
assertTrue(service.contains("func formattedAreaString(area: Double, isPyong: Bool) -> String"), "service should expose formattedAreaString API")
assertTrue(service.contains("/// - Parameter points:"), "service calculateArea should include Quick Help parameter docs")
assertTrue(service.contains("/// - Returns:"), "service APIs should include Quick Help return docs")

assertTrue(mapViewModel.contains("private let areaCalculationService: MapAreaCalculationServicing"), "MapViewModel should depend on area calculation protocol")
assertTrue(mapViewModel.contains("areaCalculationService: MapAreaCalculationServicing = MapAreaCalculationService()"), "MapViewModel init should inject default service")
assertTrue(mapViewModel.contains("areaCalculationService.calculateArea(points: points)"), "MapViewModel should delegate area calculation to service")
assertTrue(mapViewModel.contains("areaCalculationService.formattedAreaString(area: area, isPyong: isPyong)"), "MapViewModel should delegate area formatting to service")

print("PASS: map area calculation service unit checks")
