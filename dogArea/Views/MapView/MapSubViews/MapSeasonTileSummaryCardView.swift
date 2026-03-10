import SwiftUI

struct MapSeasonTileSummaryCardView: View {
    let summary: MapSeasonTileChromeSummaryPresentation
    let onOpenOverview: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(summary.title)
                    .font(.appFont(for: .ExtraBold, size: 16))
                    .foregroundStyle(MapChromePalette.primaryText)
                HStack(spacing: 8) {
                    metricChip(
                        title: "점령",
                        value: summary.occupiedValue,
                        tone: .accent,
                        accessibilityIdentifier: "map.season.summary.metric.occupied"
                    )
                    metricChip(
                        title: "유지",
                        value: summary.maintainedValue,
                        tone: .success,
                        accessibilityIdentifier: "map.season.summary.metric.maintained"
                    )
                    metricChip(
                        title: "최고",
                        value: summary.topLevelValue,
                        tone: .neutral,
                        accessibilityIdentifier: "map.season.summary.metric.topLevel"
                    )
                }
            }

            Spacer(minLength: 8)

            if let onOpenOverview {
                Button(action: onOpenOverview) {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.up.square.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("자세히")
                            .font(.appFont(for: .SemiBold, size: 11))
                    }
                    .foregroundStyle(MapChromePalette.primaryText)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("map.season.summary.openOverview")
                .accessibilityLabel("시즌 점령 지도 자세히 보기")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .mapChromeSurface(emphasized: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.season.summary.card")
        .accessibilityLabel(summary.title)
        .accessibilityValue(summary.accessibilitySummary)
    }

    /// 시즌 요약 핵심값을 작은 칩으로 렌더링합니다.
    /// - Parameters:
    ///   - title: 지표 이름입니다.
    ///   - value: 지표 값입니다.
    ///   - tone: 칩 강조 톤입니다.
    ///   - accessibilityIdentifier: UI 테스트용 식별자입니다.
    /// - Returns: 요약 지표 칩 뷰입니다.
    private func metricChip(
        title: String,
        value: String,
        tone: MapChromePillTone,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.appFont(for: .SemiBold, size: 10))
            Text(value)
                .font(.appFont(for: .SemiBold, size: 12))
        }
        .foregroundStyle(MapChromePalette.primaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .mapChromePill(tone)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
