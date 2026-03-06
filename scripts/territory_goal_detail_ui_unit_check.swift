import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func load(_ path: String) -> String {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        fputs("FAIL: cannot load \(path)\n", stderr)
        exit(1)
    }
    return text
}

let doc = load("docs/territory-goal-view-detail-ui-v1.md")
let territoryGoalView = load("dogArea/Views/HomeView/HomeSubView/TerritoryGoalView.swift")
let territoryGoalViewModel = load("dogArea/Views/HomeView/HomeSubView/TerritoryGoalViewModel.swift")
let territoryGoalOverview = load("dogArea/Views/HomeView/HomeSubView/Sections/TerritoryGoal/TerritoryGoalOverviewCardView.swift")
let areaDetailView = load("dogArea/Views/HomeView/AreaDetailView.swift")
let areaDetailViewModel = load("dogArea/Views/HomeView/HomeSubView/AreaDetailViewModel.swift")
let areaDetailSnapshotSection = load("dogArea/Views/HomeView/HomeSubView/Sections/AreaDetail/AreaDetailCatalogSnapshotSectionView.swift")
let insightService = load("dogArea/Source/Domain/Home/Services/AreaReferenceCatalogInsightService.swift")

assertTrue(doc.contains("목표 상세 보기"), "territory goal doc should distinguish home CTA copy")
assertTrue(doc.contains("TerritoryGoalActionHintCardView.swift"), "territory goal doc should describe action hint section split")

assertTrue(territoryGoalView.contains("TerritoryGoalHeaderSectionView"), "territory goal screen should use header section component")
assertTrue(territoryGoalView.contains("TerritoryGoalOverviewCardView"), "territory goal screen should use overview card component")
assertTrue(territoryGoalView.contains("TerritoryGoalInsightSectionView"), "territory goal screen should use insight section component")
assertTrue(territoryGoalView.contains("TerritoryGoalRecentListSectionView"), "territory goal screen should use recent section component")
assertTrue(territoryGoalView.contains("TerritoryGoalActionHintCardView"), "territory goal screen should use action hint card component")
assertTrue(territoryGoalOverview.contains("비교군 카탈로그 열기 >"), "territory goal screen should expose comparison catalog CTA")
assertTrue(territoryGoalOverview.contains("territory.goal.catalog"), "territory goal screen should expose catalog CTA identifier")

assertTrue(territoryGoalViewModel.contains("goalMeaningText"), "territory goal view model should describe why the goal matters")
assertTrue(territoryGoalViewModel.contains("freshnessText"), "territory goal view model should expose freshness copy")
assertTrue(territoryGoalViewModel.contains("actionBodyText"), "territory goal view model should expose next-action copy")

assertTrue(areaDetailView.contains("AreaDetailHeaderSectionView"), "area detail screen should use header section component")
assertTrue(areaDetailView.contains("AreaDetailCatalogSnapshotSectionView"), "area detail screen should use catalog snapshot section component")
assertTrue(areaDetailView.contains("AreaDetailSummaryCardView"), "area detail screen should use summary section component")
assertTrue(areaDetailView.contains("AreaDetailReferenceCatalogSectionView"), "area detail screen should use reference catalog component")
assertTrue(areaDetailView.contains("AreaDetailRecentConquestSectionView"), "area detail screen should use recent conquest component")
assertTrue(areaDetailView.contains("내용 추가 바람") == false, "area detail screen should remove placeholder copy")
assertTrue(areaDetailView.contains("screen.areaDetail"), "area detail screen should expose screen identifier")

assertTrue(areaDetailViewModel.contains("sourceDescriptionText"), "area detail view model should explain source context")
assertTrue(areaDetailViewModel.contains("freshnessText"), "area detail view model should expose data freshness")
assertTrue(areaDetailViewModel.contains("actionBody"), "area detail view model should expose actionable copy")
assertTrue(areaDetailViewModel.contains("catalogMetrics"), "area detail view model should expose catalog metric cards")
assertTrue(areaDetailViewModel.contains("currentBandTitle"), "area detail view model should expose current band summary")
assertTrue(areaDetailSnapshotSection.contains("카탈로그 스냅샷"), "area detail should label catalog snapshot section")
assertTrue(insightService.contains("AreaReferenceCatalogInsightService"), "area detail should use a dedicated catalog insight service")

print("PASS: territory goal detail UI unit checks")
