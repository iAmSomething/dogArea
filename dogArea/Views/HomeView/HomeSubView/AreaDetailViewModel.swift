import Combine
import Foundation

final class AreaDetailViewModel: ObservableObject {
    let homeViewModel: HomeViewModel
    private var cancellables: Set<AnyCancellable> = []

    /// 홈 ViewModel을 주입받아 비교군 카탈로그 상세 화면에 필요한 상태를 재사용합니다.
    /// - Parameter homeViewModel: 영역/비교군 원본 데이터를 보유한 홈 ViewModel입니다.
    init(homeViewModel: HomeViewModel) {
        self.homeViewModel = homeViewModel

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
        "\(homeViewModel.selectedPetNameWithYi)가 지금 어디쯤 왔는지 기준값과 함께 비교해보세요."
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

    var referenceSections: [AreaReferenceSection] {
        homeViewModel.areaReferenceSections
    }

    var recentAreas: [AreaMeterDTO] {
        Array(homeViewModel.myAreaList.sorted { $0.createdAt > $1.createdAt }.prefix(5))
    }

    var actionTitle: String {
        homeViewModel.nextGoalArea == nil ? "새 목표 고르기" : "다음 산책 전 체크"
    }

    var actionBody: String {
        if let nextGoal = homeViewModel.nextGoalArea {
            return "\(nextGoal.areaName)보다 조금 작은 기준부터 훑어보면 남은 \(remainingAreaText)을 얼마나 빨리 채울지 감이 잡혀요."
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
