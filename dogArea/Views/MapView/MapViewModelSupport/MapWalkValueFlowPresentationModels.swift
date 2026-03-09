import Foundation

enum MapWalkTopHUDDisplayMode: Equatable {
    case regular
    case compact
}

enum MapWalkTopHUDDisclosureMode: Equatable {
    case expandInline
    case openGuideSheet
}

struct MapWalkTopHUDMetricPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
}

struct MapWalkTopHUDPresentation: Equatable {
    let title: String
    let statusText: String
    let metrics: [MapWalkTopHUDMetricPresentation]
    let displayMode: MapWalkTopHUDDisplayMode
    let disclosureTitle: String?
    let disclosureMode: MapWalkTopHUDDisclosureMode
}

struct MapWalkActiveValueMetricPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
}

struct MapWalkActiveValuePresentation: Equatable {
    let title: String
    let summary: String
    let metrics: [MapWalkActiveValueMetricPresentation]
    let footer: String
}

struct MapWalkSavedOutcomeItemPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
}

struct MapWalkSavedOutcomePresentation: Equatable {
    let title: String
    let summary: String
    let followUpItems: [MapWalkSavedOutcomeItemPresentation]
    let primaryActionTitle: String
}

struct WalkCompletionValueItemPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
}

struct WalkCompletionValuePresentation: Equatable {
    let title: String
    let summary: String
    let items: [WalkCompletionValueItemPresentation]
    let footnote: String
}
