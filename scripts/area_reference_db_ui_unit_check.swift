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
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let areaMeters = load("dogArea/Views/HomeView/AreaMeters.swift")
let homeVM = load("dogArea/Views/HomeView/HomeViewModel.swift")
let homeView = load("dogArea/Views/HomeView/HomeView.swift")
let areaDetail = load("dogArea/Views/HomeView/AreaDetailView.swift")
let doc = load("docs/area-reference-db-ui-transition-v1.md")
let readme = load("README.md")
let migrationDoc = load("docs/supabase-migration.md")

assertTrue(areaMeters.contains("protocol AreaReferenceRepository"), "area meter module should define area reference protocol")
assertTrue(areaMeters.contains("final class SupabaseAreaReferenceRepository"), "area meter module should include supabase implementation")
assertTrue(areaMeters.contains("area_reference_catalogs"), "area meter module should fetch area_reference_catalogs")
assertTrue(areaMeters.contains("area_references"), "area meter module should fetch area_references")
assertTrue(areaMeters.contains("AreaReferenceSnapshot"), "area meter module should define snapshot model")
assertTrue(areaMeters.contains("fallbackSnapshot"), "area meter module should define fallback snapshot")
assertTrue(areaMeters.contains("isFeatured"), "area meter module should include featured field")
assertTrue(areaMeters.contains("displayOrder"), "area meter module should include display order field")
assertTrue(areaMeters.contains("init(areas: [AreaMeter]? = nil)"), "AreaMeterCollection should support injected area list")
assertTrue(homeVM.contains("areaReferenceSections"), "HomeViewModel should expose area reference sections")
assertTrue(homeVM.contains("areaReferenceSourceLabel"), "HomeViewModel should expose area source label")
assertTrue(homeVM.contains("featuredAreaCount"), "HomeViewModel should expose featured area count")
assertTrue(homeVM.contains("refreshAreaReferenceCatalogs()"), "HomeViewModel should refresh area reference catalogs")
assertTrue(homeVM.contains("nearlistMore()"), "HomeViewModel should still expose nearlistMore")
assertTrue(homeVM.contains("featuredGoalAreas"), "HomeViewModel should keep featured-goal areas")

assertTrue(homeView.contains("비교군 소스:"), "HomeView should render area source label")
assertTrue(areaDetail.contains("비교군 카탈로그"), "AreaDetail should render catalog section")
assertTrue(areaDetail.contains("viewModel.areaReferenceSections"), "AreaDetail should use DB-backed sections")

assertTrue(doc.contains("featured"), "doc should include featured policy")
assertTrue(doc.contains("display_order"), "doc should include display order policy")
assertTrue(doc.contains("Fallback"), "doc should include fallback policy")
assertTrue(readme.contains("docs/area-reference-db-ui-transition-v1.md"), "README should include area DB UI transition doc")
assertTrue(migrationDoc.contains("area_reference_catalogs"), "migration doc should include area reference catalog verification")

print("PASS: area reference DB UI transition unit checks")
