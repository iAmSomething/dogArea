import Foundation

struct Check {
    static func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() == false {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}

func load(_ path: String) -> String {
    let url = URL(fileURLWithPath: path)
    guard let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .utf8) else {
        fputs("FAIL: unable to read \(path)\n", stderr)
        exit(1)
    }
    return text
}

let root = FileManager.default.currentDirectoryPath
let mapView = load(root + "/dogArea/Views/MapView/MapView.swift")
let checklist = load(root + "/docs/release-regression-checklist-v1.md")
let spec = load(root + "/docs/map-banner-priority-queue-v1.md")

Check.assertTrue(mapView.contains("@State private var activeBanner"), "map view should keep single active banner state")
Check.assertTrue(mapView.contains("if let activeBanner"), "map view should render only one top banner slot")
Check.assertTrue(mapView.contains("topBannerView(for: activeBanner)"), "map view should route all banners through unified renderer")
Check.assertTrue(mapView.contains("prioritizedBannerCandidates"), "map view should build prioritized banner queue")
Check.assertTrue(mapView.contains("bannerAutoDismissTask"), "map view should include auto-dismiss task")
Check.assertTrue(mapView.contains("case p0") && mapView.contains("case p1"), "map view should define banner severity levels")
Check.assertTrue(mapView.contains("autoDismissAfter"), "candidate should define auto-dismiss policy")
Check.assertTrue(mapView.contains("dismissTopBanner"), "map view should support banner suppression/dismiss")

Check.assertTrue(spec.contains("최대 1개 배너"), "spec should state single-banner constraint")
Check.assertTrue(spec.contains("P0") && spec.contains("P1"), "spec should define severity tiers")
Check.assertTrue(checklist.contains("배너 우선순위 큐"), "release checklist should include banner queue regression scenario")

print("PASS: banner priority queue unit checks")
