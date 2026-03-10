import SwiftUI

struct MapSeasonTileSummarySheetView: View {
    let summary: MapSeasonTileSummaryPresentation
    let onOpenGuide: (() -> Void)?
    let onOpenDetail: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    statusChipRow
                    intensityStrip
                    summaryRow(
                        systemImageName: "square.dashed",
                        text: summary.meaningLine,
                        accessibilityIdentifier: "map.season.sheet.meaning"
                    )
                    summaryRow(
                        systemImageName: "paintpalette.fill",
                        text: summary.intensityLine,
                        accessibilityIdentifier: "map.season.sheet.intensity"
                    )
                    summaryRow(
                        systemImageName: "figure.walk",
                        text: summary.walkContributionLine,
                        accessibilityIdentifier: "map.season.sheet.relation"
                    )
                    summaryRow(
                        systemImageName: "hand.tap.fill",
                        text: summary.selectionHintLine,
                        accessibilityIdentifier: "map.season.sheet.selectionHint"
                    )
                    actionSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(Color.appBackground)
            .navigationTitle("시즌 점령 지도")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기", action: onClose)
                        .accessibilityIdentifier("map.season.sheet.close")
                }
            }
        }
        .accessibilityIdentifier("map.season.summary.sheet")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.title)
                .font(.appFont(for: .ExtraBold, size: 20))
                .foregroundStyle(Color.appInk)
            Text(summary.countLine)
                .font(.appFont(for: .SemiBold, size: 14))
                .foregroundStyle(Color.appTextDarkGray)
            Text(summary.topLevelLabel)
                .font(.appFont(for: .SemiBold, size: 12))
                .foregroundStyle(Color.appInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.appYellowPale)
                .clipShape(Capsule())
        }
    }

    private var statusChipRow: some View {
        HStack(spacing: 8) {
            statusChip(
                title: "점령",
                subtitle: "굵은 테두리",
                tone: .accent,
                accessibilityIdentifier: "map.season.sheet.status.occupied"
            )
            statusChip(
                title: "유지",
                subtitle: "점선 테두리",
                tone: .success,
                accessibilityIdentifier: "map.season.sheet.status.maintained"
            )
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let onOpenGuide {
                Button(action: onOpenGuide) {
                    actionRow(
                        systemImageName: "questionmark.circle.fill",
                        title: "시즌 규칙 다시 보기",
                        subtitle: "점령과 유지가 어떤 의미인지 설명을 엽니다."
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("map.season.sheet.openGuide")
            }

            if let onOpenDetail {
                Button(action: onOpenDetail) {
                    actionRow(
                        systemImageName: "info.circle.fill",
                        title: "대표 칸 상세 보기",
                        subtitle: "현재 가장 대표적인 칸의 상태와 다음 산책 힌트를 엽니다."
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("map.season.sheet.openDetail")
            }
        }
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
        .foregroundStyle(Color.appInk)
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
                        .foregroundStyle(Color.appTextDarkGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .accessibilityIdentifier("map.season.sheet.level.\(item.level + 1)")
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
                .foregroundStyle(Color.appTextDarkGray)
                .frame(width: 14, height: 14)
            Text(text)
                .font(.appFont(for: .Regular, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    /// 액션 행을 공통 레이아웃으로 렌더링합니다.
    /// - Parameters:
    ///   - systemImageName: 행 앞에 붙일 SF Symbol 이름입니다.
    ///   - title: 행동 제목입니다.
    ///   - subtitle: 행동 설명입니다.
    /// - Returns: sheet 액션 행 뷰입니다.
    private func actionRow(
        systemImageName: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImageName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appInk)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appFont(for: .SemiBold, size: 13))
                    .foregroundStyle(Color.appInk)
                Text(subtitle)
                    .font(.appFont(for: .Regular, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appTextLightGray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.appYellowPale.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        case 0: return 0.18
        case 1: return 0.24
        case 2: return 0.30
        default: return 0.36
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
