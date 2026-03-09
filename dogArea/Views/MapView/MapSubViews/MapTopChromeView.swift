import SwiftUI

struct MapTopChromeView: View {
    let safeAreaTopInset: CGFloat
    let weatherStatusText: String
    let isWeatherFallbackActive: Bool
    let seasonTileSummaryText: String?
    let seasonTileSummaryContent: AnyView?
    let seasonTileDetailContent: AnyView?
    let walkingHUDContent: AnyView?
    let walkingHUDDetailContent: AnyView?
    let bannerContent: AnyView?
    let statusContent: AnyView?
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MapChromeLayoutMetrics.topSectionSpacing) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: MapChromeLayoutMetrics.pillSpacing) {
                    weatherStatusPill
                    if let seasonTileSummaryText, seasonTileSummaryText.isEmpty == false {
                        seasonTileSummaryPill(text: seasonTileSummaryText)
                    }
                }

                Spacer(minLength: 12)

                MapChromeIconButton(
                    systemImageName: "slider.horizontal.3",
                    accessibilityIdentifier: "map.openSettings",
                    accessibilityLabel: "지도 설정",
                    accessibilityHint: "지도 설정 시트를 엽니다.",
                    emphasized: false,
                    action: onOpenSettings
                )
            }

            if let walkingHUDContent {
                walkingHUDContent
            }

            if let walkingHUDDetailContent {
                walkingHUDDetailContent
            }

            if let seasonTileSummaryContent {
                seasonTileSummaryContent
            }

            if let seasonTileDetailContent {
                seasonTileDetailContent
            }

            if let bannerContent {
                bannerContent
            }

            if let statusContent {
                statusContent
            }
        }
        .padding(.top, AppTabLayoutMetrics.topOverlaySpacing(safeAreaTopInset: safeAreaTopInset, extra: 10))
        .padding(.horizontal, MapChromeLayoutMetrics.horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var weatherStatusPill: some View {
        HStack(spacing: 8) {
            Image(systemName: isWeatherFallbackActive ? "exclamationmark.triangle.fill" : "cloud.sun.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(weatherStatusText)
                .font(.appFont(for: .SemiBold, size: 11))
                .lineLimit(2)
        }
        .foregroundStyle(MapChromePalette.secondaryText)
        .mapChromePill(isWeatherFallbackActive ? .neutral : .accent)
        .accessibilityLabel("지도 날씨 상태 \(weatherStatusText)")
    }

    /// 시즌 점령 지도 요약을 chrome pill로 렌더링합니다.
    /// - Parameter text: 현재 시즌 타일 요약 문구입니다.
    /// - Returns: 지도 상단에 표시할 시즌 점령 지도 요약 pill 뷰입니다.
    private func seasonTileSummaryPill(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.appFont(for: .SemiBold, size: 11))
                .lineLimit(2)
        }
        .foregroundStyle(MapChromePalette.secondaryText)
        .mapChromePill(.neutral)
    }
}
