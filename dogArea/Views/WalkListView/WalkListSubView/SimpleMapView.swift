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
        if let polygonOverlay = polygon.polygon {
            Map(
                initialPosition: MapCameraPosition.camera(
                    .init(
                        centerCoordinate: polygonOverlay.coordinate,
                        distance: max(polygonOverlay.boundingMapRect.width, 180)
                    )
                ),
                interactionModes: .all
            ) {
                ForEach(polygon.locations) { location in
                    Annotation("", coordinate: location.coordinate) {
                        VStack(spacing: 4) {
                            Image(systemName: location.pointRole == .mark ? "mappin.circle.fill" : "point.bottomleft.forward.to.point.topright.scurvepath.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text(location.pointRole == .mark ? "표시" : "이동")
                                .font(.appFont(for: .SemiBold, size: 9))
                        }
                        .foregroundStyle(locationForegroundColor(for: location))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(locationBackgroundColor(for: location))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(locationBorderColor(for: location), lineWidth: 1)
                        )
                    }
                }
                MapPolygon(polygonOverlay)
                    .stroke(Color.appYellow, lineWidth: 1)
                    .foregroundStyle(Color.appYellow.opacity(0.28))
                    .annotationTitles(.hidden)
            }
        }
    }

    /// 포인트 상태에 맞는 배경 색상을 반환합니다.
    /// - Parameter location: 현재 렌더링 중인 산책 포인트입니다.
    /// - Returns: 선택/역할 상태가 반영된 배경 색상입니다.
    private func locationBackgroundColor(for location: Location) -> Color {
        if location.id == selectedLocation {
            return Color.appYellow
        }
        return location.pointRole == .mark
            ? Color.appDynamicHex(light: 0xFFF7EB, dark: 0x431407, alpha: 0.82)
            : Color.appDynamicHex(light: 0xEFF6FF, dark: 0x1E3A8A, alpha: 0.28)
    }

    /// 포인트 상태에 맞는 외곽선 색상을 반환합니다.
    /// - Parameter location: 현재 렌더링 중인 산책 포인트입니다.
    /// - Returns: 선택/역할 상태가 반영된 외곽선 색상입니다.
    private func locationBorderColor(for location: Location) -> Color {
        if location.id == selectedLocation {
            return Color.appDynamicHex(light: 0xEAB308, dark: 0xFACC15)
        }
        return location.pointRole == .mark
            ? Color.appDynamicHex(light: 0xFED7AA, dark: 0x7C2D12)
            : Color.appDynamicHex(light: 0xBFDBFE, dark: 0x1D4ED8)
    }

    /// 포인트 상태에 맞는 전경 색상을 반환합니다.
    /// - Parameter location: 현재 렌더링 중인 산책 포인트입니다.
    /// - Returns: 선택/역할 상태가 반영된 텍스트 및 아이콘 색상입니다.
    private func locationForegroundColor(for location: Location) -> Color {
        if location.id == selectedLocation {
            return Color.appInk
        }
        return location.pointRole == .mark
            ? Color.appDynamicHex(light: 0x92400E, dark: 0xFDBA74)
            : Color.appDynamicHex(light: 0x1D4ED8, dark: 0x93C5FD)
    }
}
