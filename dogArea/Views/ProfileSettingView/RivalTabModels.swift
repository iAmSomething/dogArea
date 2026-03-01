import Foundation

enum RivalCompareScope: String, CaseIterable {
    case rival
    case friend
}

enum RivalReportReason: String, CaseIterable {
    case inappropriate = "inappropriate"
    case spam = "spam"
    case suspectedCheat = "suspected_cheat"

    var title: String {
        switch self {
        case .inappropriate:
            return "부적절한 활동"
        case .spam:
            return "스팸/도배"
        case .suspectedCheat:
            return "기록 조작 의심"
        }
    }
}

struct RivalModerationLogEntry: Codable {
    let action: String
    let aliasCode: String
    let reason: String?
    let createdAt: TimeInterval
}
