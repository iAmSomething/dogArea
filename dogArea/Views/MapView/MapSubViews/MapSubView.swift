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
        MapRenderBudgetProbe.recordMapSubViewBodyEvaluationIfNeeded()
        let activeWalkSnapshot = viewModel.activeWalkPointSnapshot
        let selectedPolygonSnapshot = viewModel.walkPointSnapshot(for: viewModel.polygon)

        return Map(position: $viewModel.cameraPosition, interactionModes: .all) {
            if viewModel.isSeasonTileMapVisible {
                ForEach(viewModel.seasonTileMapTiles) { tile in
                    MapPolygon(tile.polygon)
                        .foregroundStyle(
                            viewModel.seasonTileFillColor(for: tile)
                                .opacity(viewModel.seasonTileFillOpacity(for: tile))
                        )
                        .annotationTitles(.hidden)
                }
            }
            if let walkArea = viewModel.polygon.polygon {
                if viewModel.showOnlyOne {
                    MapPolygon(walkArea)
                        .stroke(Color.appYellow, lineWidth: 0.5)
                        .foregroundStyle(Color.appYellow.opacity(0.3))
                        .annotationTitles(.visible)
                } else {
                    ForEach(viewModel.renderablePolygonOverlays) { item in
                        if let polygon = item.polygon {
                            MapPolygon(polygon)
                                .stroke(Color.appYellow, lineWidth: 0.5)
                                .foregroundStyle(Color.appYellow.opacity(0.3))
                                .annotationTitles(.visible)
                        }
                    }
                }
            }
            if viewModel.isSeasonTileMapVisible {
                ForEach(viewModel.seasonTileMapTiles) { tile in
                    MapPolygon(tile.polygon)
                        .stroke(
                            viewModel.seasonTileStrokeColor(for: tile),
                            style: viewModel.seasonTileStrokeStyle(for: tile)
                        )
                        .annotationTitles(.hidden)
                }
                ForEach(viewModel.seasonTileMapTiles.filter(viewModel.isSeasonTileSelected)) { tile in
                    MapPolygon(tile.polygon)
                        .stroke(
                            viewModel.seasonTileSelectionHaloColor(for: tile),
                            style: viewModel.seasonTileSelectionHaloStyle(for: tile)
                        )
                        .annotationTitles(.hidden)
                }
                ForEach(viewModel.seasonTileMapTiles) { tile in
                    Annotation("", coordinate: tile.centerCoordinate) {
                        seasonTileSelectionHitTarget(for: tile)
                    }
                    .annotationTitles(.hidden)
                }
            }
            if viewModel.isWalking, activeWalkSnapshot.hasRenderableRoute {
                MapPolyline(coordinates: activeWalkSnapshot.routeCoordinates)
                    .stroke(routeStrokeColor, style: routeStrokeStyle)
            }
            if let walkArea = viewModel.polygon.polygon {
                if viewModel.showOnlyOne {
                    if selectedPolygonSnapshot.hasRenderableRoute {
                        MapPolyline(coordinates: selectedPolygonSnapshot.routeCoordinates)
                            .stroke(routeStrokeColor, style: routeStrokeStyle)
                    }
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
                    ForEach(selectedPolygonSnapshot.markLocations) { location in
                        Annotation("", coordinate: location.coordinate) {
                            PositionMarkerView()
                        }
                    }
                } else {
                    ForEach(viewModel.centerLocations.indices, id: \.self) { index in
                        Annotation("", coordinate: viewModel.centerLocations[index].center) {
                            MapClusterPulseAnnotationView(
                                count: viewModel.centerLocations[index].sumLocs.count,
                                isReducedMotion: viewModel.isMapMotionReduced,
                                animationDuration: viewModel.clusterMotionAnimationDuration,
                                motionState: viewModel.clusterMotionState
                            ) {
                                viewModel.fetchSelectedPolygonList(for: viewModel.centerLocations[index])
                            }
                        }
                    }
                }
            } else {
                if viewModel.isWalking == false, activeWalkSnapshot.hasRenderableRoute {
                    MapPolyline(coordinates: activeWalkSnapshot.routeCoordinates)
                        .stroke(routeStrokeColor, style: routeStrokeStyle)
                }
                ForEach(activeWalkSnapshot.markLocations) { location in
                    Annotation("", coordinate: location.coordinate) {
                        PositionMarkerView()
                            .onTapGesture {
                                viewModel.selectedMarker = location
                                myAlert.callAlert(type: .annotationSelected(location))
                            }
                    }
                }
            }
            if viewModel.isNearbyHotspotFeatureAvailable && viewModel.nearbyHotspotEnabled {
                ForEach(viewModel.renderableNearbyHotspotNodes) { hotspot in
                    Annotation("", coordinate: hotspot.centerCoordinate) {
                        nearbyHotspotAnnotationView(for: hotspot)
                    }
                }
            }
            ForEach(viewModel.activeCaptureRipples()) { ripple in
                Annotation("", coordinate: ripple.coordinate) {
                    MapCaptureRippleAnnotationView(
                        duration: viewModel.captureRippleDuration,
                        isReducedMotion: viewModel.isMapMotionReduced
                    )
                    .allowsHitTesting(false)
                }
            }
            if viewModel.isWalking {
                ForEach(viewModel.activeTrailMarkers) { trail in
                    Annotation("", coordinate: trail.coordinate) {
                        MapTrailMarkerAnnotationView(
                            trail: trail,
                            isReducedMotion: viewModel.isMapMotionReduced
                        )
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
        }
        .mapControls {
//            mapControls
        }
    }

    private var routeStrokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [9, 6])
    }

    private var routeStrokeColor: Color {
        Color.appGreen.opacity(0.9)
    }

    /// 시즌 타일 선택용 hit target을 렌더링합니다.
    /// - Parameter tile: 상세 패널을 열 시즌 타일 표현입니다.
    /// - Returns: 지도 위에서 탭 가능한 시즌 타일 선택 뷰입니다.
    private func seasonTileSelectionHitTarget(for tile: MapSeasonTilePresentation) -> some View {
        Button {
            viewModel.toggleSelectedSeasonTile(tile)
        } label: {
            Circle()
                .fill(Color.appInk.opacity(0.001))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityIdentifier("map.season.tile.hitTarget")
        .accessibilityLabel("\(tile.intensityLabel) \(tile.status.rawValue) 칸 상세 보기")
        .accessibilityHint("이 칸이 왜 이런 상태인지와 다음 산책 힌트를 엽니다.")
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
        VStack {
            MapUserLocationButton()
        }
        .mapControlVisibility(.visible)
    }
}

private struct MapCaptureRippleAnnotationView: View {
    let duration: Double
    let isReducedMotion: Bool
    @State private var isAnimated: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.appYellow.opacity(0.7), lineWidth: 2)
                .frame(width: 16, height: 16)
                .scaleEffect(isAnimated ? 2.7 : 0.5)
                .opacity(isAnimated ? 0.0 : 1.0)
            Circle()
                .stroke(Color.appYellowPale.opacity(0.55), lineWidth: 1.5)
                .frame(width: 12, height: 12)
                .scaleEffect(isAnimated ? 2.2 : 0.6)
                .opacity(isAnimated ? 0.0 : 0.8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: effectiveDuration)) {
                isAnimated = true
            }
        }
    }

    private var effectiveDuration: Double {
        isReducedMotion ? max(0.18, duration * 0.65) : duration
    }
}
