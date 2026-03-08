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
    @State private var clusterPulseActive: Bool = false

    var body: some View {
        MapRenderBudgetProbe.recordMapSubViewBodyEvaluationIfNeeded()
        let activeWalkSnapshot = viewModel.activeWalkPointSnapshot
        let selectedPolygonSnapshot = viewModel.walkPointSnapshot(for: viewModel.polygon)

        return Map(position: $viewModel.cameraPosition, interactionModes: .all) {
            if viewModel.isWalking, activeWalkSnapshot.hasRenderableRoute {
                MapPolyline(coordinates: activeWalkSnapshot.routeCoordinates)
                    .stroke(routeStrokeColor, style: routeStrokeStyle)
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
            if viewModel.isHeatmapVisibleInMapUI {
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
            if let walkArea = viewModel.polygon.polygon {
                if viewModel.showOnlyOne {
                    if selectedPolygonSnapshot.hasRenderableRoute {
                        MapPolyline(coordinates: selectedPolygonSnapshot.routeCoordinates)
                            .stroke(routeStrokeColor, style: routeStrokeStyle)
                    }
                    ForEach(selectedPolygonSnapshot.markLocations) { location in
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
                } else {
                    ForEach(viewModel.centerLocations.indices, id: \.self) { index in
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
                        if let polygon = item.polygon {
                            MapPolygon(polygon)
                                .stroke(Color.appYellow, lineWidth: 0.5)
                                .foregroundStyle(Color.appYellow.opacity(0.3))
                                .annotationTitles(.visible)
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
        }
        .mapControls {
//            mapControls
        }
        .overlay(alignment: .topLeading) {
            if MapRenderBudgetProbe.isEnabled {
                MapRenderBudgetProbeOverlay()
            }
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

private struct MapTrailMarkerAnnotationView: View {
    private struct VisualState {
        let scale: Double
        let opacity: Double
    }

    let trail: MapViewModel.TrailMarker
    let isReducedMotion: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: tickInterval)) { context in
            let visualState = makeVisualState(at: context.date)
            Image(systemName: "pawprint.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.appInk.opacity(0.8))
                .scaleEffect(visualState.scale)
                .opacity(visualState.opacity)
        }
    }

    /// 기준 시각에 맞춰 트레일 마커의 스케일/투명도 상태를 계산합니다.
    /// - Parameter now: 현재 렌더 기준 시각입니다.
    /// - Returns: 현재 시점에 적용할 트레일 마커 시각 상태입니다.
    private func makeVisualState(at now: Date) -> VisualState {
        let age = max(0, now.timeIntervalSince1970 - trail.recordedAt)
        let ratio = min(1.0, max(0.0, age / 5.0))
        return VisualState(
            scale: 0.95 + ((1.0 - ratio) * 0.25),
            opacity: 0.75 - (ratio * 0.65)
        )
    }

    private var tickInterval: TimeInterval {
        isReducedMotion ? 0.5 : 0.25
    }
}

private struct MapRenderBudgetProbeOverlay: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                Text(MapRenderBudgetProbe.currentCountText())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.72))
                    .clipShape(Capsule())
                    .accessibilityIdentifier("map.debug.renderCount")
            }

            Button("reset") {
                MapRenderBudgetProbe.reset()
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.72))
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .accessibilityIdentifier("map.debug.renderCount.reset")
        }
        .padding(.top, 12)
        .padding(.leading, 12)
    }
}

enum MapRenderBudgetProbe {
    private static let lock = NSLock()
    private static var mapSubViewBodyCount: Int = 0

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITest.TrackMapRenderBudget")
    }

    /// 지도 루트 body 평가 카운터를 초기화합니다.
    static func resetIfNeeded() {
        guard isEnabled else { return }
        lock.lock()
        mapSubViewBodyCount = 0
        lock.unlock()
    }

    /// UI 테스트가 안정화 이후 구간만 다시 측정할 수 있도록 카운터를 즉시 초기화합니다.
    static func reset() {
        guard isEnabled else { return }
        lock.lock()
        mapSubViewBodyCount = 0
        lock.unlock()
    }

    /// 지도 루트 body 평가 횟수를 누적합니다.
    static func recordMapSubViewBodyEvaluationIfNeeded() {
        guard isEnabled else { return }
        lock.lock()
        mapSubViewBodyCount += 1
        lock.unlock()
    }

    /// 현재 누적된 지도 루트 body 평가 횟수를 문자열로 반환합니다.
    /// - Returns: UI 테스트 접근성에서 읽을 수 있는 평가 횟수 문자열입니다.
    static func currentCountText() -> String {
        lock.lock()
        let count = mapSubViewBodyCount
        lock.unlock()
        return "\(count)"
    }
}
