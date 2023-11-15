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
            if let currentLoc = viewModel.location {
                Annotation("", coordinate: currentLoc.coordinate) {
                    Circle().foregroundStyle(Color.appHotPink)
                        .frame(width: 20, height: 20)
                        .animation(.linear(duration: 1), value: currentLoc.coordinate)
                        .shadow(radius: 5)
                }
            }
            if let walkArea = viewModel.polygon.polygon{
                if viewModel.showOnlyOne {
                    ForEach(viewModel.polygon.locations) { location in
                        Annotation("", coordinate: location.coordinate) {
                            PositionMarkerView()
                        }
                    }
                    MapPolygon(walkArea)
                        .stroke(Color.appYellow, lineWidth: 0.5)
                        .foregroundStyle(Color.appYellow.opacity(0.3))
                        .annotationTitles(.visible)
                    Annotation("", coordinate: walkArea.coordinate) {
                        VStack {
                            Image(.dogPrint)
                                .resizable()
                                .frame(width: 20, height: 20)
                                .background(Color.appGreen)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                            Text("\(viewModel.polygon.createdAt.createdAtTimeYYMMDD)")
                                .font(.appFont(for: .Regular, size: 12))
                                .foregroundColor(.appTextDarkGray)
                        }
                    }
                }
                else {
                    ForEach(viewModel.polygonList) { item in
                        if let p  = item.polygon {
                            MapPolygon(p)
                                .stroke(Color.appYellow, lineWidth: 0.5)
                                .foregroundStyle(Color.appYellow.opacity(0.3))
                                .annotationTitles(.visible)
                            Annotation("", coordinate: p.coordinate) {
                                VStack {
                                    Image(.dogPrint)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .background(Color.appGreen)
                                        .cornerRadius(10)
                                        .shadow(radius: 5)
                                    Text("\(item.createdAt.createdAtTimeYYMMDD)")
                                        .font(.appFont(for: .Regular, size: 12))
                                        .foregroundColor(.appTextDarkGray)
                                }.onTapGesture {
                                    let distance = p.boundingMapRect.width
                                    viewModel.setRegion(p.coordinate, distance: distance)
                                }
                            }
                        }
                    }
                }
            }
            else { 
                ForEach(viewModel.polygon.locations) { location in
                    Annotation("", coordinate: location.coordinate) {
                        PositionMarkerView()
                            .onTapGesture {
                                viewModel.selectedMarker = location
                                myAlert.callAlert(type: .annotationSelected(location))
                            }
                    }
                }
            }
        }.mapControls {
//            mapControls
        }
    }
    var mapControls: some View {
        VStack{
            MapUserLocationButton()
            
        }.mapControlVisibility(.visible)
    }
}

