import Foundation

enum SeasonGuideEntryContext: String, Equatable {
    case firstSeasonVisit
    case mapSummary
    case homeSeasonCard
}

struct SeasonGuideConceptPresentation: Identifiable, Equatable {
    let id: String
    let iconName: String
    let title: String
    let body: String
}

struct SeasonGuideFlowStepPresentation: Identifiable, Equatable {
    let stepNumber: Int
    let title: String
    let body: String

    var id: Int { stepNumber }
}

struct SeasonGuidePresentation: Identifiable, Equatable {
    let context: SeasonGuideEntryContext
    let badgeText: String
    let title: String
    let subtitle: String
    let heroLine: String
    let conceptItems: [SeasonGuideConceptPresentation]
    let flowSteps: [SeasonGuideFlowStepPresentation]
    let repeatWalkRuleLine: String
    let revisitLine: String

    var id: String { context.rawValue }
}
