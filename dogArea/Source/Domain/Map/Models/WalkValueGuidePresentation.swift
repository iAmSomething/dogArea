import Foundation

enum WalkValueGuideEntryContext: String, Equatable {
    case firstWalkVisit
    case mapHelperReentry
}

struct WalkValueGuideFlowStepPresentation: Identifiable, Equatable {
    let id: String
    let badgeText: String
    let title: String
    let body: String
}

struct WalkValueGuidePresentation: Identifiable, Equatable {
    let context: WalkValueGuideEntryContext
    let badgeText: String
    let title: String
    let subtitle: String
    let heroLine: String
    let flowSteps: [WalkValueGuideFlowStepPresentation]
    let compactPolicyLine: String
    let revisitLine: String

    var id: String { context.rawValue }
}
