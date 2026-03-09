//
//  MapSettingView.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import SwiftUI

struct MapSettingView: View {
    @Environment(\.dismiss) var dismiss

    @ObservedObject var viewModel: MapViewModel
    @ObservedObject var myAlert: CustomAlertViewModel

    private let toggleColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 130), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    toggleGrid
                    autoEndPolicySection
                    if viewModel.isHeatmapFeatureAvailable && viewModel.heatmapEnabled {
                        heatmapLegendSection
                    }
                    polygonHistorySection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .safeAreaPadding(.bottom, 18)
            }
            .scrollIndicators(.visible)
        }
        .background(Color.appBackground)
        .accessibilityIdentifier("sheet.map.settings")
    }

    private var header: some View {
        HStack {
            Text("지도 설정")
                .font(.appFont(for: .ExtraBold, size: 20))
                .foregroundStyle(Color.appInk)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.appTextDarkGray)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("map.settings.close")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var toggleGrid: some View {
        LazyVGrid(columns: toggleColumns, spacing: 8) {
            toggleChip(
                title: viewModel.showOnlyOne ? "모든 폴리곤 보기" : "단일 폴리곤 보기",
                isActive: viewModel.showOnlyOne
            ) {
                viewModel.showOnlyOne.toggle()
            }
            toggleChip(
                title: "시즌 점령 지도",
                isActive: viewModel.isHeatmapFeatureAvailable && viewModel.heatmapEnabled
            ) {
                viewModel.toggleHeatmapEnabled()
            }
            toggleChip(
                title: "근처 핫스팟",
                isActive: viewModel.isNearbyHotspotFeatureAvailable && viewModel.nearbyHotspotEnabled
            ) {
                viewModel.toggleNearbyHotspotEnabled()
            }
            toggleChip(
                title: "위치 공유",
                isActive: viewModel.isNearbyHotspotFeatureAvailable && viewModel.locationSharingEnabled
            ) {
                viewModel.toggleLocationSharing()
            }
            toggleChip(
                title: "시작 카운트다운",
                isActive: viewModel.walkStartCountdownEnabled
            ) {
                viewModel.toggleWalkStartCountdown()
            }
            toggleChip(
                title: viewModel.walkPointRecordMode.title,
                isActive: viewModel.isAutoPointRecordMode
            ) {
                viewModel.toggleWalkPointRecordMode()
            }
            toggleChip(
                title: viewModel.isAddPointLongPressModeEnabled ? "길게 눌러 영역 추가" : "영역 추가 후 실행 취소",
                isActive: viewModel.isAddPointLongPressModeEnabled
            ) {
                viewModel.toggleAddPointLongPressMode()
            }
            toggleChip(
                title: "모션 축소",
                isActive: viewModel.isMapMotionReduced
            ) {
                viewModel.toggleMapMotionReduced()
            }
            Text("자동 종료 기준 적용 중")
                .font(.appFont(for: .SemiBold, size: 13))
                .foregroundStyle(Color.appInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.appYellowPale)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var autoEndPolicySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.autoEndPolicySummaryText)
                .font(.appFont(for: .Medium, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            Text(viewModel.autoEndPolicyHintText)
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextLightGray)
        }
        .appCardSurface()
    }

    private var heatmapLegendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("시즌 점령 지도 범례")
                .font(.appFont(for: .SemiBold, size: 14))
                .foregroundStyle(Color.appInk)
            Text(viewModel.seasonTileStatusSummaryText)
                .font(.appFont(for: .Medium, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            Text(viewModel.seasonTileSummaryCardPresentation.meaningLine)
                .font(.appFont(for: .Regular, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            Text(viewModel.seasonTileSummaryCardPresentation.walkContributionLine)
                .font(.appFont(for: .Regular, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 8) {
                legendStatusChip(
                    title: "점령",
                    subtitle: "굵은 테두리",
                    strokeColor: Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74),
                    dash: []
                )
                legendStatusChip(
                    title: "유지",
                    subtitle: "점선 테두리",
                    strokeColor: Color.appDynamicHex(light: 0x0F766E, dark: 0x5EEAD4),
                    dash: [5, 3]
                )
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.seasonTileLegendItems) { item in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(viewModel.heatmapColor(for: Double(item.level + 1) / 4.0))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(
                                            item.status == "점령"
                                                ? Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74)
                                                : Color.appDynamicHex(light: 0x0F766E, dark: 0x5EEAD4),
                                            style: StrokeStyle(
                                                lineWidth: item.status == "점령" ? 1.8 : 1.2,
                                                dash: item.status == "점령" ? [] : [5, 3]
                                            )
                                        )
                                )
                                .frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.label) \(item.status)")
                                    .font(.appFont(for: .Light, size: 10))
                                    .foregroundStyle(Color.appTextDarkGray)
                                Text(item.description)
                                    .font(.appFont(for: .Light, size: 9))
                                    .foregroundStyle(Color.appTextLightGray)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.appYellowPale.opacity(0.45))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .appCardSurface()
    }

    /// 점령/유지 상태를 설정 시트용 시각 샘플로 렌더링합니다.
    /// - Parameters:
    ///   - title: 상태 이름입니다.
    ///   - subtitle: 상태를 읽는 보조 설명입니다.
    ///   - strokeColor: 테두리 색상입니다.
    ///   - dash: 점선 패턴입니다.
    /// - Returns: 상태 샘플 칩 뷰입니다.
    private func legendStatusChip(
        title: String,
        subtitle: String,
        strokeColor: Color,
        dash: [CGFloat]
    ) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.appYellowPale.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            strokeColor,
                            style: StrokeStyle(lineWidth: dash.isEmpty ? 1.8 : 1.2, dash: dash)
                        )
                )
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.appFont(for: .SemiBold, size: 11))
                    .foregroundStyle(Color.appInk)
                Text(subtitle)
                    .font(.appFont(for: .Light, size: 9))
                    .foregroundStyle(Color.appTextDarkGray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.appYellowPale.opacity(0.35))
        .cornerRadius(8)
    }

    private var polygonHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("산책 기록")
                .font(.appFont(for: .SemiBold, size: 16))
            if viewModel.polygonList.isEmpty {
                Text("저장된 산책 기록이 없어요.")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
            } else {
                ForEach(viewModel.polygonList) { item in
                    HStack(spacing: 10) {
                        Button {
                            focus(on: item)
                        } label: {
                            Text(item.createdAt.createdAtTimeDescription)
                                .font(.appFont(for: .Regular, size: 12))
                                .foregroundStyle(Color.appInk)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            dismiss()
                            myAlert.callAlert(type: .deletePolygon(item.id))
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.appRed)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .appCardSurface()
    }

    /// 토글 칩 버튼을 렌더링합니다.
    private func toggleChip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.appFont(for: .SemiBold, size: 13))
                .foregroundStyle(isActive ? Color.appInk : Color.appTextDarkGray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isActive ? Color.appYellow : Color.appTextLightGray.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// 선택한 폴리곤을 지도 중심으로 포커싱합니다.
    private func focus(on item: Polygon) {
        viewModel.polygon = item
        if let polygonCenter = item.polygon?.coordinate,
           let distance = item.polygon?.boundingMapRect.width {
            viewModel.setRegion(polygonCenter, distance: distance)
        }
    }
}
