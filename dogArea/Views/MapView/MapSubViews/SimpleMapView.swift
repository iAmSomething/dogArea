//
//  SimpleMapView.swift
//  dogArea
//
//  Created by 김태훈 on 11/10/23.
//

import SwiftUI
import _MapKit_SwiftUI

struct SimpleMapView: View {
    @State var polygon: Polygon
    var body: some View {
        if let p = self.polygon.polygon{
            Map(initialPosition: MapCameraPosition.camera(.init(centerCoordinate: p.coordinate, distance: p.boundingMapRect.width)),
                interactionModes: .all){
                            ForEach(polygon.locations) { location in
                                Annotation("", coordinate: location.coordinate) {
                                    PositionMarkerView()
                                }
                            }
                if let walkArea = polygon.polygon{
                    MapPolygon(walkArea)
                        .stroke(.blue, lineWidth: 0.5)
                        .foregroundStyle(.cyan.opacity(0.3))
                        .annotationTitles(.visible)
                }
            }
        }
    }
}
