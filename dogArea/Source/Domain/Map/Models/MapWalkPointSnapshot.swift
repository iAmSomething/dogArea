//
//  MapWalkPointSnapshot.swift
//  dogArea
//
//  Created by Codex on 3/8/26.
//

import Foundation
import CoreLocation

struct MapWalkPointSnapshot {
    let polygonID: UUID
    let sourcePointCount: Int
    let routeCoordinates: [CLLocationCoordinate2D]
    let markLocations: [Location]

    var hasRenderableRoute: Bool {
        routeCoordinates.count > 1
    }
}
