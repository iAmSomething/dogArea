import Foundation

func load(_ path: String) -> String {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(path)
    return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
}

func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() == false {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let mapView = load("dogArea/Views/MapView/MapView.swift")
let startButtonView = load("dogArea/Views/MapView/MapSubViews/StartButtonView.swift")
let topChromeView = load("dogArea/Views/MapView/MapSubViews/MapTopChromeView.swift")
let floatingControlView = load("dogArea/Views/MapView/MapSubViews/MapFloatingControlColumnView.swift")
let styleView = load("dogArea/Views/MapView/MapSubViews/MapChromeSurfaceStyle.swift")

assertTrue(mapView.contains("MapTopChromeView("), "MapView should compose top chrome through MapTopChromeView")
assertTrue(mapView.contains("mapFloatingControlOverlay"), "MapView should expose floating control overlay")
assertTrue(mapView.contains("selectedPolygonTrayOverlay"), "MapView should separate selected polygon tray overlay")
assertTrue(!mapView.contains("Text(\"내 위치 보기\")"), "MapView should remove legacy text-based recenter CTA")
assertTrue(topChromeView.contains("map.openSettings"), "top chrome should preserve map settings accessibility identifier")
assertTrue(floatingControlView.contains("map.recenter"), "floating controls should expose recenter accessibility identifier")
assertTrue(floatingControlView.contains("map.addPoint"), "floating controls should expose add-point accessibility identifier")
assertTrue(startButtonView.contains("mapChromeSurface(emphasized: viewModel.isWalking)"), "StartButtonView should render inside shared chrome surface")
assertTrue(startButtonView.contains("map.walk.primaryAction"), "StartButtonView should preserve map primary action accessibility identifier")
assertTrue(styleView.contains("MapChromeIconButton"), "shared map chrome style should provide icon button component")

print("PASS: map chrome hierarchy unit checks")
