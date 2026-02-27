//
//  MapSubView.swift
//  dogArea
//
//  Created by 김태훈 on 11/10/23.
//

import Foundation
import SwiftUI
import _MapKit_SwiftUI
import Combine

struct MapSubView: View {
    @ObservedObject var myAlert: CustomAlertViewModel
    @ObservedObject var viewModel: MapViewModel
    @State private var motionNow: Date = Date()
    @State private var clusterPulseActive: Bool = false
    private let motionTicker = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    var body: some View {
        Map(position: $viewModel.cameraPosition,
            interactionModes: .all){
            ForEach(viewModel.activeCaptureRipples(at: motionNow)) { ripple in
                let progress = viewModel.captureRippleProgress(for: ripple, now: motionNow)
                Annotation("", coordinate: ripple.coordinate) {
                    ZStack {
                        Circle()
                            .stroke(Color.appYellow.opacity(0.7), lineWidth: 2)
                            .frame(width: 16, height: 16)
                            .scaleEffect(0.5 + (progress * 2.2))
                            .opacity(1.0 - progress)
                        Circle()
                            .stroke(Color.appYellowPale.opacity(0.55), lineWidth: 1.5)
                            .frame(width: 12, height: 12)
                            .scaleEffect(0.6 + (progress * 1.6))
                            .opacity(max(0.0, 0.8 - progress))
                    }
                    .allowsHitTesting(false)
                }
            }
            if viewModel.isWalking {
                ForEach(viewModel.activeTrailMarkers) { trail in
                    Annotation("", coordinate: trail.coordinate) {
                        Image(.dogPrint)
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(Color.appTextDarkGray)
                            .scaleEffect(trail.scale)
                            .opacity(trail.opacity)
                            .allowsHitTesting(false)
                    }
                }
            }
            if let currentLoc = viewModel.location {
                Annotation("", coordinate: currentLoc.coordinate) {
                    Circle().foregroundStyle(Color.appHotPink)
                        .frame(width: 20, height: 20)
                        .animation(.linear(duration: 1), value: currentLoc.coordinate)
                        .shadow(radius: 5)
                }
            }
            if !viewModel.isWalking && !viewModel.showOnlyOne && viewModel.isHeatmapFeatureAvailable && viewModel.heatmapEnabled {
                ForEach(viewModel.heatmapCells) { cell in
                    MapCircle(center: cell.centerCoordinate, radius: 75)
                        .foregroundStyle(
                            viewModel.heatmapColor(for: cell.score)
                                .opacity(viewModel.heatmapOpacity(for: cell.score))
                        )
                }
            }
            if viewModel.isNearbyHotspotFeatureAvailable && viewModel.nearbyHotspotEnabled {
                ForEach(viewModel.nearbyHotspots) { spot in
                    MapCircle(center: spot.centerCoordinate, radius: 100)
                        .foregroundStyle(
                            viewModel.nearbyHotspotColor(for: spot.intensity)
                                .opacity(viewModel.nearbyHotspotOpacity(for: spot.intensity))
                        )
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
                    ForEach(viewModel.centerLocations.indices, id:\.self) { index in
                        Annotation("", coordinate: viewModel.centerLocations[index].center) {
                            VStack {
                                Image(.dogPrint)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .background(Color.appGreen)
                                    .cornerRadius(10)
                                    .shadow(radius: 5)
                                if viewModel.centerLocations[index].sumLocs.count == 1 {
                                    
                                } else {
                                    Text("\(viewModel.centerLocations[index].sumLocs.count)")
                                        .font(.appFont(for: .Regular, size: 12))
                                        .foregroundColor(.appTextDarkGray)
                                }
                            }
                            .scaleEffect(clusterPulseScale)
                            .opacity(clusterPulseOpacity)
                            .onTapGesture {
                                viewModel.fetchSelectedPolygonList(for: viewModel.centerLocations[index])
                            }
                        }
                    }
                    ForEach(viewModel.renderablePolygonOverlays) { item in
                        if let p  = item.polygon {
                            MapPolygon(p)
                                .stroke(Color.appYellow, lineWidth: 0.5)
                                .foregroundStyle(Color.appYellow.opacity(0.3))
                                .annotationTitles(.visible)
//                            Annotation("", coordinate: p.coordinate) {
//                                VStack {
//                                    Image(.dogPrint)
//                                        .resizable()
//                                        .frame(width: 20, height: 20)
//                                        .background(Color.appGreen)
//                                        .cornerRadius(10)
//                                        .shadow(radius: 5)
//                                    Text("\(item.createdAt.createdAtTimeYYMMDD)")
//                                        .font(.appFont(for: .Regular, size: 12))
//                                        .foregroundColor(.appTextDarkGray)
//                                }.onTapGesture {
//                                    let distance = p.boundingMapRect.width
//                                    viewModel.setRegion(p.coordinate, distance: distance)
//                                }
//                            }
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
        .onReceive(motionTicker) { now in
            motionNow = now
            viewModel.compactMapMotionArtifacts(now: now)
        }
        .onChange(of: viewModel.clusterMotionToken) { _ in
            guard viewModel.clusterMotionTransition != .none else { return }
            withAnimation(.easeOut(duration: viewModel.clusterMotionAnimationDuration)) {
                clusterPulseActive = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + viewModel.clusterMotionAnimationDuration) {
                withAnimation(.easeOut(duration: viewModel.clusterMotionAnimationDuration)) {
                    clusterPulseActive = false
                }
            }
        }
    }

    private var clusterPulseScale: Double {
        guard clusterPulseActive else { return 1.0 }
        switch viewModel.clusterMotionTransition {
        case .decompose: return 0.92
        case .merge: return 1.08
        case .none: return 1.0
        }
    }

    private var clusterPulseOpacity: Double {
        guard clusterPulseActive else { return 1.0 }
        return viewModel.isMapMotionReduced ? 0.92 : 0.82
    }

    var mapControls: some View {
        VStack{
            MapUserLocationButton()
            
        }.mapControlVisibility(.visible)
    }
}
