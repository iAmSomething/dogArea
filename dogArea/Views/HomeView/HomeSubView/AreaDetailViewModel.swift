import Combine
import Foundation

final class AreaDetailViewModel: ObservableObject {
    let homeViewModel: HomeViewModel
    private var cancellables: Set<AnyCancellable> = []
    private let insightService: AreaReferenceCatalogInsightServicing

    /// 홈 ViewModel을 주입받아 비교군 카탈로그 상세 화면에 필요한 상태를 재사용합니다.
    /// - Parameters:
    ///   - homeViewModel: 영역/비교군 원본 데이터를 보유한 홈 ViewModel입니다.
    ///   - insightService: 비교군 카탈로그 해석 로직을 제공하는 서비스입니다.
    init(
        homeViewModel: HomeViewModel,
        insightService: AreaReferenceCatalogInsightServicing = AreaReferenceCatalogInsightService()
    ) {
        self.homeViewModel = homeViewModel
        self.insightService = insightService

        homeViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var title: String {
        "비교군 카탈로그"
    }

    var subtitle: String {
        "\(homeViewModel.selectedPetNameWithYi)가 비교군 카탈로그에서 어느 기준 사이에 있는지 확인하고 다음 시즌 목표를 조정해보세요."
    }

    var selectedPetBadgeText: String {
        "선택 반려견 기준 · \(homeViewModel.selectedPetName)"
    }

    var sourceText: String {
        homeViewModel.areaReferenceSource == .remote ? "DB 비교군" : "로컬 비교군 (Fallback)"
    }

    var sourceDescriptionText: String {
        homeViewModel.areaReferenceSource == .remote
        ? "운영 중인 비교군 카탈로그를 기준으로 다음 목표를 계산했어요."
        : "원격 비교군을 불러오지 못해 로컬 비교군으로 대체했어요."
    }

    var freshnessText: String {
        guard let lastUpdatedAt = homeViewModel.areaReferenceLastUpdatedAt else {
            return "갱신 정보 없음"
        }
        return Self.relativeTimestampFormatter.localizedString(for: lastUpdatedAt, relativeTo: Date()) + " 갱신"
    }

    private var insight: AreaReferenceCatalogInsight {
        insightService.makeInsight(
            currentArea: homeViewModel.myArea,
            nextGoal: homeViewModel.nextGoalArea,
            sections: homeViewModel.areaReferenceSections,
            featuredCount: homeViewModel.featuredAreaCount
        )
    }

    var currentAreaText: String {
        homeViewModel.myArea.area.calculatedAreaString
    }

    var currentAreaName: String {
        homeViewModel.myArea.areaName
    }

    var nextGoalNameText: String {
        homeViewModel.nextGoalArea?.areaName ?? "현재 목표 완료"
    }

    var nextGoalAreaText: String {
        homeViewModel.nextGoalArea?.area.calculatedAreaString ?? "다음 비교군 선택 필요"
    }

    var remainingAreaText: String {
        homeViewModel.remainingAreaToGoal.calculatedAreaString
    }

    var featuredSummaryText: String {
        "Featured \(homeViewModel.featuredAreaCount)개를 우선 기준으로 보여줘요."
    }

    var coverageSummaryText: String {
        insight.coverageSummaryText
    }

    var currentBandTitle: String {
        insight.currentBandTitle
    }

    var currentBandBody: String {
        insight.currentBandBody
    }

    var catalogMetrics: [AreaReferenceCatalogMetricItem] {
        insight.metrics
    }

    var referenceSections: [AreaReferenceCatalogSectionViewData] {
        insight.displaySections
    }

    var recentAreas: [AreaMeterDTO] {
        Array(homeViewModel.myAreaList.sorted { $0.createdAt > $1.createdAt }.prefix(5))
    }

    var actionTitle: String {
        homeViewModel.nextGoalArea == nil ? "새 목표 고르기" : "다음 산책 전 체크"
    }

    var actionBody: String {
        if let nextGoal = homeViewModel.nextGoalArea {
            return "\(nextGoal.areaName) 기준선이 붙은 행과 그보다 작은 기준선을 같이 보면, 남은 \(remainingAreaText)을 한 번의 산책으로 채울지 두 번으로 나눌지 판단하기 쉬워집니다."
        }
        return "현재 기준으로는 가장 큰 목표까지 도달했어요. 비교군 카탈로그에서 더 큰 기준을 찾아 다음 시즌 목표를 잡아보세요."
    }

    /// 최신 비교군/영역 스냅샷을 다시 불러옵니다.
    func refresh() {
        homeViewModel.refreshAreaList()
        homeViewModel.refreshAreaReferenceCatalogs()
    }

    private static let relativeTimestampFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()
}
