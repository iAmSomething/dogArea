import Foundation
import Combine

final class TerritoryGoalViewModel: ObservableObject {
    let homeViewModel: HomeViewModel
    let entryContext: TerritoryGoalEntryContext?
    private var cancellables: Set<AnyCancellable> = []

    /// 홈 ViewModel을 주입받아 Territory Goal 화면에서 재사용합니다.
    /// - Parameters:
    ///   - homeViewModel: 기존 데이터/비즈니스 로직을 보유한 홈 ViewModel입니다.
    ///   - entryContext: 위젯 등 외부 진입에서 전달된 상세 진입 맥락입니다.
    init(homeViewModel: HomeViewModel, entryContext: TerritoryGoalEntryContext? = nil) {
        self.homeViewModel = homeViewModel
        self.entryContext = entryContext

        homeViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var title: String {
        "\(homeViewModel.selectedPetNameWithYi)의 영역 목표"
    }

    var subtitle: String {
        "다음 산책에서 무엇을 우선해야 하는지 한 번에 정리해드릴게요."
    }

    var selectedPetBadgeText: String {
        "선택 반려견 기준 · \(homeViewModel.selectedPetName)"
    }

    var headerEyebrowText: String {
        "영역 목표 상세"
    }

    var entryBannerMessage: String? {
        entryContext?.bannerMessage
    }

    var entryBannerIsWarning: Bool {
        entryContext?.isWarning ?? false
    }

    var goalMeaningText: String {
        if let nextGoal = homeViewModel.nextGoalArea {
            return "다음 랜드마크 \(nextGoal.areaName)까지 \(remainingAreaText) 남았어요."
        }
        return "현재 비교군 기준으로는 가장 큰 목표까지 도달했어요."
    }

    var areaSourceText: String {
        "\(homeViewModel.areaReferenceSourceLabel) · 우선 추천 \(homeViewModel.featuredAreaCount)개"
    }

    var freshnessText: String {
        guard let lastUpdatedAt = homeViewModel.areaReferenceLastUpdatedAt else {
            return "갱신 정보 없음"
        }
        return Self.relativeTimestampFormatter.localizedString(for: lastUpdatedAt, relativeTo: Date()) + " 갱신"
    }

    var isFallbackSource: Bool {
        homeViewModel.areaReferenceSource == .fallback
    }

    var currentAreaText: String {
        homeViewModel.myArea.area.calculatedAreaString
    }

    var nextGoalNameText: String {
        homeViewModel.nextGoalArea?.areaName ?? "목표 없음"
    }

    var nextGoalAreaText: String {
        homeViewModel.nextGoalArea?.area.calculatedAreaString ?? "완료"
    }

    var remainingAreaText: String {
        homeViewModel.remainingAreaToGoal.calculatedAreaString
    }

    var progressRatio: Double {
        homeViewModel.goalProgressRatio
    }

    var progressPercentText: String {
        "\(Int(progressRatio * 100))%"
    }

    var recentAreas: [AreaMeterDTO] {
        Array(homeViewModel.myAreaList.sorted { $0.createdAt > $1.createdAt }.prefix(5))
    }

    var progressMessageText: String {
        if let nextGoal = homeViewModel.nextGoalArea {
            return "\(nextGoal.areaName)까지 \(remainingAreaText)만 더 확보하면 돼요. 다음 산책 경로를 조금만 넓혀보세요."
        }
        return "새 비교군을 확인해 다음 목표를 다시 정해보세요."
    }

    var recentInsightDetailText: String {
        if let latest = recentAreas.first {
            return "최신 정복: \(latest.areaName)"
        }
        return "최근 정복 기록이 아직 없어요."
    }

    var sourceInsightDetailText: String {
        isFallbackSource ? "지금은 온라인 비교 구역을 불러오지 못해 기본 비교 구역으로 안내하고 있어요." : "운영 중인 비교 구역을 사용 중이에요."
    }

    var freshnessInsightDetailText: String {
        isFallbackSource ? "지금은 기본 비교 구역 기준으로 보여드리고 있어요." : "최근 동기화 시각 기준입니다."
    }

    var actionTitle: String {
        isFallbackSource ? "비교군 재확인 필요" : "다음 산책 액션"
    }

    var actionBodyText: String {
        if let nextGoal = homeViewModel.nextGoalArea {
            return "\(nextGoal.areaName)을 목표로 남은 \(remainingAreaText)을 채우는 경로를 잡아보세요. 비교군 카탈로그에서 그보다 조금 작은 기준도 함께 확인하면 우선순위 판단이 쉬워집니다."
        }
        return "현재 목표를 모두 달성했어요. 비교군 카탈로그로 이동해 더 큰 기준을 다음 목표로 골라보세요."
    }

    /// 최신 데이터 스냅샷을 갱신합니다.
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
