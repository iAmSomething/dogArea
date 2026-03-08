import Foundation

enum HomeMissionGuideEntryContext: String, Equatable {
    case firstVisitCoach
    case helpButtonReentry
}

struct HomeMissionGuideCoachPresentation: Equatable {
    let badgeText: String
    let title: String
    let summaryText: String
    let primaryActionTitle: String
    let dismissActionTitle: String
}

struct HomeMissionGuideAxisPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
}

struct HomeMissionGuideComparisonPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
}

struct HomeMissionGuideStepPresentation: Identifiable, Equatable {
    let id: String
    let badgeText: String
    let title: String
    let body: String
}

struct HomeMissionGuidePresentation: Identifiable, Equatable {
    let context: HomeMissionGuideEntryContext
    let badgeText: String
    let title: String
    let subtitle: String
    let heroLine: String
    let coachPresentation: HomeMissionGuideCoachPresentation
    let sections: [HomeMissionGuideAxisPresentation]
    let comparisons: [HomeMissionGuideComparisonPresentation]
    let steps: [HomeMissionGuideStepPresentation]
    let revisitLine: String

    var id: String { context.rawValue }
}
