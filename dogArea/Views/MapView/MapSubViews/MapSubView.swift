//
//  MapSubView.swift
//  dogArea
//
//  Created by 김태훈 on 11/10/23.
//

import Foundation
import SwiftUI
import _MapKit_SwiftUI

struct MapSubView: View {
    @ObservedObject var myAlert: CustomAlertViewModel
    @ObservedObject var viewModel: MapViewModel
    var body: some View {
        Map(position: $viewModel.cameraPosition,
            interactionModes: .all){
            ForEach(viewModel.polygon.locations) { location in
                Annotation("", coordinate: location.coordinate) {
                    PositionMarkerView()
                        .onTapGesture {
                            viewModel.selectedMarker = location
                            myAlert.callAlert(type: .annotationSelected(location))
                        }
                }
            }
            if let walkArea = viewModel.polygon.polygon{
                if viewModel.showOnlyOne {
                    MapPolygon(walkArea)
                        .stroke(.blue, lineWidth: 0.5)
                        .foregroundStyle(.cyan.opacity(0.3))
                        .annotationTitles(.visible)
                }
                else {
                    ForEach(viewModel.polygonList) { item in
                        if let p  = item.polygon {
                            MapPolygon(p)
                                .stroke(.blue, lineWidth: 0.5)
                                .foregroundStyle(.cyan.opacity(0.3))              .annotationTitles(.visible)
                        }
                    }
                }
            }
            else { }
        }.mapControls {
            mapControls
        }
    }
    var mapControls: some View {
        VStack{
            MapUserLocationButton()
            
        }.mapControlVisibility(.visible)
    }
}

