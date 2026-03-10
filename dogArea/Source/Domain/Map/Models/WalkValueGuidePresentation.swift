import Foundation

enum WalkValueGuideEntryContext: String, Equatable {
    case firstWalkVisit
    case mapHelperReentry
    case settingsReentry
}

struct WalkValueGuideUnderstandingCardPresentation: Identifiable, Equatable {
    let id: String
    let badgeText: String
    let title: String
    let body: String
}

struct WalkValueGuideRecordModeOptionPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
}

struct WalkValueGuidePresentation: Identifiable, Equatable {
    let context: WalkValueGuideEntryContext
    let badgeText: String
    let title: String
    let subtitle: String
    let understandingCards: [WalkValueGuideUnderstandingCardPresentation]
    let stepTwoTitle: String
    let stepTwoSubtitle: String
    let recordModeOptions: [WalkValueGuideRecordModeOptionPresentation]
    let defaultPointRecordModeRawValue: String
    let recordModeFootnote: String
    let sharingDefaultTitle: String
    let sharingDefaultBody: String
    let sharingDefaultFootnote: String
    let revisitLine: String

    var id: String { context.rawValue }
}
