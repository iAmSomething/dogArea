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

func loadMany(_ relativePaths: [String]) -> String {
    relativePaths.map(load).joined(separator: "\n")
}

let areaMeters = load("dogArea/Source/Domain/Home/Models/AreaReferenceModels.swift")
let supabaseInfra = loadMany([
    "dogArea/Source/Infrastructure/Supabase/SupabaseInfrastructure.swift",
    "dogArea/Source/Infrastructure/Supabase/Services/SupabaseWidgetAndAreaServices.swift"
])
let homeVM = loadMany([
    "dogArea/Views/HomeView/HomeViewModel.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+SessionLifecycle.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+AreaProgress.swift",
    "dogArea/Views/HomeView/HomeViewModelSupport/HomeViewModel+IndoorMissionFlow.swift",
    "dogArea/Source/Domain/Home/Models/HomeMissionModels.swift",
    "dogArea/Source/Domain/Home/Stores/IndoorMissionStore.swift",
    "dogArea/Source/Domain/Home/Stores/SeasonMotionStore.swift"
])
let homeView = loadMany([
    "dogArea/Views/HomeView/HomeView.swift",
    "dogArea/Views/HomeView/HomeSubView/HomeGoalTrackerCardView.swift"
])
let areaDetail = load("dogArea/Views/HomeView/AreaDetailView.swift")
let areaDetailViewModel = load("dogArea/Views/HomeView/HomeSubView/AreaDetailViewModel.swift")
let areaDetailCatalogSection = load("dogArea/Views/HomeView/HomeSubView/Sections/AreaDetail/AreaDetailReferenceCatalogSectionView.swift")
let doc = load("docs/area-reference-db-ui-transition-v1.md")
let readme = load("README.md")
let migrationDoc = load("docs/supabase-migration.md")

assertTrue(areaMeters.contains("protocol AreaReferenceRepository"), "area meter module should define area reference protocol")
assertTrue(areaMeters.contains("AreaReferenceSnapshot"), "area meter module should define snapshot model")
assertTrue(areaMeters.contains("isFeatured"), "area meter module should include featured field")
assertTrue(areaMeters.contains("displayOrder"), "area meter module should include display order field")
assertTrue(areaMeters.contains("init(areas: [AreaMeter]? = nil)"), "AreaMeterCollection should support injected area list")
assertTrue(supabaseInfra.contains("final class SupabaseAreaReferenceRepository"), "supabase infrastructure should include area reference implementation")
assertTrue(supabaseInfra.contains("area_reference_catalogs"), "supabase infrastructure should fetch area_reference_catalogs")
assertTrue(supabaseInfra.contains("area_references"), "supabase infrastructure should fetch area_references")
assertTrue(supabaseInfra.contains("fallbackSnapshot"), "supabase infrastructure should define fallback snapshot")
assertTrue(homeVM.contains("areaReferenceSections"), "HomeViewModel should expose area reference sections")
assertTrue(homeVM.contains("areaReferenceSource"), "HomeViewModel should expose area reference source enum state")
assertTrue(homeVM.contains("areaReferenceSourceLabel"), "HomeViewModel should expose area source label")
assertTrue(homeVM.contains("areaReferenceLastUpdatedAt"), "HomeViewModel should expose area source freshness")
assertTrue(homeVM.contains("featuredAreaCount"), "HomeViewModel should expose featured area count")
assertTrue(homeVM.contains("refreshAreaReferenceCatalogs()"), "HomeViewModel should refresh area reference catalogs")
assertTrue(homeVM.contains("nearlistMore()"), "HomeViewModel should still expose nearlistMore")
assertTrue(homeVM.contains("featuredGoalAreas"), "HomeViewModel should keep featured-goal areas")

assertTrue(homeView.contains("비교 기준:"), "HomeView should render area source label")
assertTrue(areaDetailCatalogSection.contains("비교군 카탈로그"), "AreaDetail should render catalog section")
assertTrue(areaDetail.contains("AreaDetailReferenceCatalogSectionView"), "AreaDetail should use catalog section component")
assertTrue(areaDetailViewModel.contains("referenceSections"), "AreaDetailViewModel should expose DB-backed sections")
assertTrue(areaDetailViewModel.contains("freshnessText"), "AreaDetailViewModel should expose freshness copy")

assertTrue(doc.contains("featured"), "doc should include featured policy")
assertTrue(doc.contains("display_order"), "doc should include display order policy")
assertTrue(doc.contains("fallback 정책"), "doc should include fallback policy")
assertTrue(readme.contains("docs/area-reference-db-ui-transition-v1.md"), "README should include area DB UI transition doc")
assertTrue(migrationDoc.contains("area_reference_catalogs"), "migration doc should include area reference catalog verification")

print("PASS: area reference DB UI transition unit checks")
