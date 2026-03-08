import Foundation

struct HomeWalkPrimaryLoopMetricPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let detail: String
}

struct HomeWalkPrimaryLoopPillarPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
}

struct HomeWalkPrimaryLoopPresentation: Equatable {
    let badgeText: String
    let title: String
    let summaryText: String
    let metrics: [HomeWalkPrimaryLoopMetricPresentation]
    let pillars: [HomeWalkPrimaryLoopPillarPresentation]
    let secondaryFlowText: String
    let accessibilityText: String
}
