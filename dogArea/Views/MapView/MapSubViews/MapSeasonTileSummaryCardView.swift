import SwiftUI

struct MapSeasonTileSummaryCardView: View {
    let summary: MapSeasonTileSummaryPresentation
    let onOpenDetail: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.title)
                        .font(.appFont(for: .ExtraBold, size: 17))
                        .foregroundStyle(MapChromePalette.primaryText)
                    Text(summary.countLine)
                        .font(.appFont(for: .SemiBold, size: 13))
                        .foregroundStyle(MapChromePalette.secondaryText)
                }
                Spacer(minLength: 12)
                Text(summary.topLevelLabel)
                    .font(.appFont(for: .SemiBold, size: 12))
                    .foregroundStyle(MapChromePalette.primaryText)
                    .mapChromePill(.accent)
            }

            HStack(spacing: 8) {
                statusChip(
                    title: "점령",
                    subtitle: "굵은 테두리",
                    tone: .accent,
                    accessibilityIdentifier: "map.season.summary.status.occupied"
                )
                statusChip(
                    title: "유지",
                    subtitle: "점선 테두리",
                    tone: .success,
                    accessibilityIdentifier: "map.season.summary.status.maintained"
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                intensityStrip
                summaryRow(
                    systemImageName: "square.dashed",
                    text: summary.meaningLine,
                    accessibilityIdentifier: "map.season.summary.meaning"
                )
                summaryRow(
                    systemImageName: "paintpalette.fill",
                    text: summary.intensityLine,
                    accessibilityIdentifier: "map.season.summary.intensity"
                )
                summaryRow(
                    systemImageName: "figure.walk",
                    text: summary.walkContributionLine,
                    accessibilityIdentifier: "map.season.summary.relation"
                )
                summaryRow(
                    systemImageName: "hand.tap.fill",
                    text: summary.selectionHintLine,
                    accessibilityIdentifier: "map.season.summary.selectionHint"
                )
                if let onOpenDetail {
                    Button(action: onOpenDetail) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("대표 칸 상세 보기")
                                .font(.appFont(for: .SemiBold, size: 12))
                        }
                        .foregroundStyle(Color.appInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(Color.appYellowPale.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("map.season.summary.openDetail")
                }
            }
        }
        .padding(14)
        .mapChromeSurface(emphasized: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.season.summary.card")
    }

    /// 시즌 타일 상태를 짧은 칩으로 표현합니다.
    /// - Parameters:
    ///   - title: 상태 이름입니다.
    ///   - subtitle: 상태를 읽는 보조 문구입니다.
    ///   - tone: 칩 강조 톤입니다.
    ///   - accessibilityIdentifier: UI 테스트용 식별자입니다.
    /// - Returns: 상태 칩 뷰입니다.
    private func statusChip(
        title: String,
        subtitle: String,
        tone: MapChromePillTone,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.appFont(for: .SemiBold, size: 12))
            Text(subtitle)
                .font(.appFont(for: .Regular, size: 10))
        }
        .foregroundStyle(MapChromePalette.primaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mapChromePill(tone)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    /// 시즌 타일 4단계 강도를 작은 스트립으로 노출합니다.
    /// - Returns: 단계별 색 강도를 보여주는 스트립 뷰입니다.
    private var intensityStrip: some View {
        HStack(spacing: 8) {
            ForEach(summary.legendItems) { item in
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(intensityColor(for: item).opacity(intensityOpacity(for: item)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(
                                    intensityStrokeColor(for: item),
                                    style: intensityStrokeStyle(for: item)
                                )
                        )
                        .frame(height: 16)
                    Text(item.title)
                        .font(.appFont(for: .SemiBold, size: 10))
                        .foregroundStyle(MapChromePalette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .accessibilityIdentifier("map.season.summary.level.\(item.level + 1)")
            }
        }
    }

    /// 지도 상단 카드의 정보 행을 렌더링합니다.
    /// - Parameters:
    ///   - systemImageName: 행 앞에 붙일 SF Symbol 이름입니다.
    ///   - text: 설명 문구입니다.
    ///   - accessibilityIdentifier: UI 테스트용 식별자입니다.
    /// - Returns: 아이콘과 문구가 결합된 정보 행 뷰입니다.
    private func summaryRow(
        systemImageName: String,
        text: String,
        accessibilityIdentifier: String
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImageName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MapChromePalette.secondaryText)
                .frame(width: 14, height: 14)
            Text(text)
                .font(.appFont(for: .Regular, size: 11))
                .foregroundStyle(MapChromePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    /// 범례 단계에 맞는 채움 색을 계산합니다.
    /// - Parameter item: 단계/상태 정보입니다.
    /// - Returns: 단계에 대응하는 채움 색입니다.
    private func intensityColor(for item: MapSeasonTileLegendPresentation) -> Color {
        switch (item.level, item.status) {
        case (0, _): return Color.appGreen
        case (1, _): return Color.appYellowPale
        case (2, .occupied): return Color.appPeach
        case (2, _): return Color.appYellow
        case (3, .occupied): return Color.appRed
        default: return Color.appPeach
        }
    }

    /// 범례 단계에 맞는 채움 투명도를 계산합니다.
    /// - Parameter item: 단계/상태 정보입니다.
    /// - Returns: 단계에 대응하는 채움 투명도입니다.
    private func intensityOpacity(for item: MapSeasonTileLegendPresentation) -> Double {
        switch item.level {
        case 0: return 0.24
        case 1: return 0.34
        case 2: return 0.42
        default: return 0.52
        }
    }

    /// 범례 단계에 맞는 테두리 색을 계산합니다.
    /// - Parameter item: 단계/상태 정보입니다.
    /// - Returns: 단계에 대응하는 테두리 색입니다.
    private func intensityStrokeColor(for item: MapSeasonTileLegendPresentation) -> Color {
        switch item.status {
        case .occupied:
            return Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74)
        case .maintained:
            return Color.appDynamicHex(light: 0x0F766E, dark: 0x5EEAD4)
        }
    }

    /// 범례 단계에 맞는 테두리 스타일을 계산합니다.
    /// - Parameter item: 단계/상태 정보입니다.
    /// - Returns: 단계에 대응하는 테두리 스트로크 스타일입니다.
    private func intensityStrokeStyle(for item: MapSeasonTileLegendPresentation) -> StrokeStyle {
        switch item.status {
        case .occupied:
            return StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
        case .maintained:
            return StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round, dash: [5, 3])
        }
    }
}
