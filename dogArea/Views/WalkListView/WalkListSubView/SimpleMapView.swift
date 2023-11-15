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
    @Binding var selectedLocation: UUID?
    var body: some View {
        if let p = self.polygon.polygon{
            Map(initialPosition: MapCameraPosition.camera(.init(centerCoordinate: p.coordinate, distance: p.boundingMapRect.width)),
                interactionModes: .all){
                            ForEach(polygon.locations) { location in
                                Annotation("", coordinate: location.coordinate) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(location.id == selectedLocation ? Color.appPeach : Color.appYellowPale)
                                        Text("💦").font(.appFont(for: .Bold, size: 10))
                                            .padding(5)
                                    }
                                }
                            }
                if let walkArea = polygon.polygon{
                    MapPolygon(walkArea)
                        .stroke(Color.appYellow, lineWidth: 0.5)
                        .foregroundStyle(Color.appYellow.opacity(0.3))
                        .annotationTitles(.visible)
                }
            }
        }
    }
}
extension CLLocationCoordinate2D : Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }    
}
