import Foundation
import Combine

final class TerritoryGoalViewModel: ObservableObject {
    let homeViewModel: HomeViewModel
    private var cancellables: Set<AnyCancellable> = []

    /// 홈 ViewModel을 주입받아 Territory Goal 화면에서 재사용합니다.
    /// - Parameter homeViewModel: 기존 데이터/비즈니스 로직을 보유한 홈 ViewModel입니다.
    init(homeViewModel: HomeViewModel) {
        self.homeViewModel = homeViewModel

        homeViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var title: String {
        "\(homeViewModel.selectedPetNameWithYi)의 영역"
    }

    var subtitle: String {
        "\(homeViewModel.selectedPetNameWithYi)가 정복한 영역을 확인해보세요!"
    }

    var selectedPetBadgeText: String {
        "🐾 선택 반려견 기준 · \(homeViewModel.selectedPetName)"
    }

    var areaSourceText: String {
        "\(homeViewModel.areaReferenceSourceLabel) · Featured \(homeViewModel.featuredAreaCount)개"
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
        Array(homeViewModel.myAreaList.sorted { $0.createdAt > $1.createdAt }.prefix(3))
    }

    /// 최신 데이터 스냅샷을 갱신합니다.
    func refresh() {
        homeViewModel.refreshAreaList()
        homeViewModel.refreshAreaReferenceCatalogs()
    }
}
