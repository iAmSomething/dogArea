import Foundation

/// 홈 미션이 어떤 방식으로 진행되는지 구분하는 상위 분류입니다.
enum HomeMissionTrackingModeKind: String, Equatable {
    case automatic
    case manual
}

/// 홈/지도/위젯에서 재사용할 미션 추적 방식 프레젠테이션입니다.
struct HomeMissionTrackingModePresentation: Identifiable, Equatable {
    let id: String
    let kind: HomeMissionTrackingModeKind
    let badgeText: String
    let title: String
    let subtitle: String
    let iconSystemName: String
    let detailLines: [String]
}
