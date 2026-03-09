import SwiftUI

private struct MapWalkingElapsedTimeValueText: View {
    let viewModel: MapViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(viewModel.displayedWalkElapsedTime(at: context.date).simpleWalkingTimeInterval)
                .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                .foregroundStyle(MapChromePalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .monospacedDigit()
        }
    }
}

struct MapWalkActiveValueCardView: View {
    let presentation: MapWalkTopHUDPresentation
    let viewModel: MapViewModel
    let onOpenGuide: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            singleLineBody
            twoLineBody
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(MapChromePalette.surfaceBackground)
        .overlay(
            RoundedRectangle(cornerRadius: MapChromeLayoutMetrics.secondaryCornerRadius, style: .continuous)
                .stroke(MapChromePalette.surfaceBorder, lineWidth: 0.9)
        )
        .clipShape(RoundedRectangle(cornerRadius: MapChromeLayoutMetrics.secondaryCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: MapChromeLayoutMetrics.secondaryCornerRadius, style: .continuous))
        .onTapGesture(perform: onOpenGuide)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.walk.activeValue.card")
        .accessibilityHint("탭하면 산책 기록 설명을 엽니다.")
    }

    private var singleLineBody: some View {
        HStack(spacing: 8) {
            statusBadge
            metricRow
            if let guideAffordanceTitle = presentation.guideAffordanceTitle {
                guideAffordanceButton(title: guideAffordanceTitle)
            }
        }
    }

    private var twoLineBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                statusBadge
                Spacer(minLength: 8)
                if let guideAffordanceTitle = presentation.guideAffordanceTitle {
                    guideAffordanceButton(title: guideAffordanceTitle)
                }
            }

            metricRow
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.appGreen)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(presentation.title)
                    .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .headline))
                    .foregroundStyle(MapChromePalette.primaryText)
                    .lineLimit(1)
                if presentation.displayMode == .regular {
                    Text(presentation.statusText)
                        .font(.appScaledFont(for: .Regular, size: 10, relativeTo: .caption))
                        .foregroundStyle(MapChromePalette.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricRow: some View {
        HStack(spacing: 6) {
            if let durationMetric = metric(withID: "duration") {
                compactMetricChip(durationMetric, valueOverride: AnyView(MapWalkingElapsedTimeValueText(viewModel: viewModel)))
            }
            if let areaMetric = metric(withID: "area") {
                compactMetricChip(areaMetric)
            }
            if let pointsMetric = metric(withID: "points") {
                compactMetricChip(pointsMetric)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 요청한 metric 식별자에 해당하는 프레젠테이션 값을 반환합니다.
    /// - Parameter id: 조회할 metric 식별자입니다.
    /// - Returns: 식별자와 일치하는 첫 metric입니다.
    private func metric(withID id: String) -> MapWalkTopHUDMetricPresentation? {
        presentation.metrics.first(where: { $0.id == id })
    }

    /// slim HUD 안에서 metric pill을 렌더링합니다.
    /// - Parameters:
    ///   - metric: 표시할 metric 프레젠테이션입니다.
    ///   - valueOverride: 기본 문자열 대신 렌더링할 값 뷰입니다.
    /// - Returns: title/value를 담은 slim metric pill입니다.
    private func compactMetricChip(
        _ metric: MapWalkTopHUDMetricPresentation,
        valueOverride: AnyView? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title)
                .font(.appScaledFont(for: .SemiBold, size: 8, relativeTo: .caption2))
                .foregroundStyle(MapChromePalette.secondaryText)
                .lineLimit(1)
            if let valueOverride {
                valueOverride
            } else {
                Text(metric.value)
                    .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                    .foregroundStyle(MapChromePalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(MapChromePalette.neutralPillBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MapChromePalette.surfaceBorder.opacity(0.72), lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 산책 가치 가이드 재진입 affordance를 렌더링합니다.
    /// - Parameter title: 버튼에 노출할 문구입니다.
    /// - Returns: slim HUD 상단에 배치할 가이드 affordance 버튼입니다.
    private func guideAffordanceButton(title: String) -> some View {
        Button(action: onOpenGuide) {
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.appScaledFont(for: .SemiBold, size: 10, relativeTo: .caption))
            }
            .foregroundStyle(MapChromePalette.primaryText)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("map.walk.activeValue.openGuide")
    }
}
