import Foundation

enum HomeQuestWidgetTab: String, CaseIterable, Identifiable {
    case daily
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily:
            return "일일"
        case .weekly:
            return "주간"
        }
    }
}
