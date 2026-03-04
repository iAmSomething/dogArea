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
    private let motionTicker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        Map(position: $viewModel.cameraPosition,
            interactionModes: .all){
            if viewModel.isWalking, viewModel.activeWalkRouteCoordinates.count > 1 {
                MapPolyline(coordinates: viewModel.activeWalkRouteCoordinates)
                    .stroke(routeStrokeColor, style: routeStrokeStyle)
            }
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
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.appInk.opacity(0.8))
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
                        .animation(.linear(duration: 1), value: currentLoc.timestamp)
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
                ForEach(viewModel.renderableNearbyHotspotNodes) { hotspot in
                    Annotation("", coordinate: hotspot.centerCoordinate) {
                        nearbyHotspotAnnotationView(for: hotspot)
                    }
                }
            }
            if let walkArea = viewModel.polygon.polygon{
                if viewModel.showOnlyOne {
                    if viewModel.routeCoordinates(for: viewModel.polygon).count > 1 {
                        MapPolyline(coordinates: viewModel.routeCoordinates(for: viewModel.polygon))
                            .stroke(routeStrokeColor, style: routeStrokeStyle)
                    }
                    ForEach(viewModel.markLocations(for: viewModel.polygon)) { location in
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
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .frame(width: 24, height: 24)
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
                                Image(systemName: "pawprint.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.white)
                                    .frame(width: 24, height: 24)
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
                        }
                    }
                }
            }
            else { 
                if viewModel.isWalking == false, viewModel.activeWalkRouteCoordinates.count > 1 {
                    MapPolyline(coordinates: viewModel.activeWalkRouteCoordinates)
                        .stroke(routeStrokeColor, style: routeStrokeStyle)
                }
                ForEach(viewModel.activeWalkMarkLocations) { location in
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
            guard viewModel.shouldDriveMapMotionTicker else { return }
            motionNow = now
            viewModel.compactMapMotionArtifacts(now: now)
        }
        .onChange(of: viewModel.clusterMotionToken) {
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

    private var routeStrokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [9, 6])
    }

    private var routeStrokeColor: Color {
        Color.appGreen.opacity(0.9)
    }

    /// 핫스팟 렌더 노드를 지도 어노테이션 뷰로 구성합니다.
    /// - Parameter hotspot: 렌더링할 핫스팟 노드입니다.
    /// - Returns: 선택 상태/시각 상태가 반영된 어노테이션 뷰입니다.
    @ViewBuilder
    private func nearbyHotspotAnnotationView(for hotspot: NearbyHotspotRenderNode) -> some View {
        let isSelected = viewModel.selectedNearbyHotspotID == hotspot.id
        let diameter = nearbyHotspotMarkerDiameter(for: hotspot)
        let fill = viewModel.nearbyHotspotMarkerColor(for: hotspot.intensity, visualState: hotspot.visualState)
        let border = viewModel.nearbyHotspotMarkerBorderColor(for: hotspot.visualState)
        let dashPattern = viewModel.nearbyHotspotMarkerDashPattern(for: hotspot.visualState)
        let opacity = viewModel.nearbyHotspotMarkerOpacity(for: hotspot.intensity, visualState: hotspot.visualState)

        ZStack {
            if isSelected {
                Circle()
                    .stroke(Color.appYellow.opacity(0.95), lineWidth: 2.6)
                    .frame(width: diameter + 12, height: diameter + 12)
            }

            Circle()
                .fill(fill.opacity(opacity))
                .frame(width: diameter, height: diameter)

            Circle()
                .stroke(
                    border,
                    style: StrokeStyle(
                        lineWidth: isSelected ? 2.2 : 1.5,
                        dash: dashPattern
                    )
                )
                .frame(width: diameter, height: diameter)

            if hotspot.isCluster {
                Text("\(hotspot.count)")
                    .font(.appFont(for: .SemiBold, size: 12))
                    .foregroundStyle(Color.appInk)
                    .minimumScaleFactor(0.7)
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.appInk.opacity(0.92))
            }
        }
        .frame(
            minWidth: 44,
            idealWidth: max(44, diameter),
            minHeight: 44,
            idealHeight: max(44, diameter)
        )
        .contentShape(Circle())
        .onTapGesture {
            viewModel.toggleNearbyHotspotSelection(hotspot)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.nearbyHotspotStatusText(for: hotspot))
    }

    /// 핫스팟 유형에 따라 마커 직경을 계산합니다.
    /// - Parameter hotspot: 렌더링 대상 핫스팟 노드입니다.
    /// - Returns: 클러스터 여부/활동 수가 반영된 마커 직경 포인트 값입니다.
    private func nearbyHotspotMarkerDiameter(for hotspot: NearbyHotspotRenderNode) -> CGFloat {
        if hotspot.isCluster {
            return min(58, 42 + CGFloat(min(16, hotspot.count / 3)))
        }
        return 40
    }

    var mapControls: some View {
        VStack{
            MapUserLocationButton()
            
        }.mapControlVisibility(.visible)
    }
}
