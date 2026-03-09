import SwiftUI

struct MapWalkActiveValueCardView: View {
    let presentation: MapWalkActiveValuePresentation
    let durationValueOverride: AnyView?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(presentation.title)
                .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .headline))
                .foregroundStyle(MapChromePalette.primaryText)
                .lineLimit(2)
            Text(presentation.summary)
                .font(.appScaledFont(for: .Regular, size: 10, relativeTo: .caption))
                .foregroundStyle(MapChromePalette.secondaryText)
                .lineLimit(2)

            HStack(spacing: 6) {
                if let durationMetric = metric(withID: "duration") {
                    compactMetricChip(durationMetric, valueOverride: durationValueOverride)
                }
                if let pointsMetric = metric(withID: "points") {
                    compactMetricChip(pointsMetric)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .mapChromePill(.neutral)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.walk.activeValue.card")
    }

    /// 요청한 metric 식별자에 해당하는 프레젠테이션 값을 반환합니다.
    /// - Parameter id: 조회할 metric 식별자입니다.
    /// - Returns: 식별자와 일치하는 첫 metric입니다.
    private func metric(withID id: String) -> MapWalkActiveValueMetricPresentation? {
        presentation.metrics.first(where: { $0.id == id })
    }

    /// compact 하단 컨트롤러 안에서 보여줄 작은 metric chip을 렌더링합니다.
    /// - Parameters:
    ///   - metric: chip에 표시할 metric 프레젠테이션입니다.
    ///   - valueOverride: 기본 문자열 대신 렌더링할 값 뷰입니다.
    /// - Returns: metric 제목과 값을 담은 compact chip입니다.
    private func compactMetricChip(
        _ metric: MapWalkActiveValueMetricPresentation,
        valueOverride: AnyView? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title)
                .font(.appScaledFont(for: .SemiBold, size: 9, relativeTo: .caption2))
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
        .padding(.vertical, 6)
        .background(MapChromePalette.neutralPillBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MapChromePalette.surfaceBorder.opacity(0.72), lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
