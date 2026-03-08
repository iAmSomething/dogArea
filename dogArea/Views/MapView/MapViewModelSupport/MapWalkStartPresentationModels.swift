import Foundation

struct MapWalkStartPillarPresentation: Identifiable, Equatable {
    let id: String
    let title: String
}

struct MapWalkStartPresentation: Equatable {
    let selectedPetTitle: String
    let selectedPetMessage: String
    let meaningTitle: String
    let meaningMessage: String
    let pillars: [MapWalkStartPillarPresentation]
    let secondaryFlowText: String
    let walkingStatusText: String
    let endAlertMessage: String
}
