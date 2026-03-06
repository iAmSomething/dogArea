import SwiftUI

struct AreaDetailSummaryCardView: View {
    let currentAreaText: String
    let currentAreaName: String
    let nextGoalNameText: String
    let nextGoalAreaText: String
    let remainingAreaText: String
    let featuredSummaryText: String
    let coverageSummaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("현재 위치와 다음 기준")
                    .font(.appScaledFont(for: .SemiBold, size: 20, relativeTo: .headline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x7C2D12, dark: 0xFED7AA))
                Text("목표 카드가 아니라, 비교군 기준으로 지금 위치를 읽기 쉽게 정리한 요약입니다.")
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
            }

            VStack(spacing: 12) {
                AreaDetailMetricRowView(
                    title: "현재 영역",
                    value: currentAreaText,
                    detail: currentAreaName
                )
                AreaDetailMetricRowView(
                    title: "다음 기준",
                    value: nextGoalNameText,
                    detail: nextGoalAreaText
                )
                AreaDetailMetricRowView(
                    title: "남은 면적",
                    value: remainingAreaText,
                    detail: "현재 면적에서 다음 기준까지 필요한 차이"
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(featuredSummaryText)
                    .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFED7AA))
                Text(coverageSummaryText)
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x431407, alpha: 0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xFED7AA, dark: 0x7C2D12), lineWidth: 1)
        )
    }
}

private struct AreaDetailMetricRowView: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
                Spacer(minLength: 0)
                Text(value)
                    .font(.appScaledFont(for: .SemiBold, size: 20, relativeTo: .title3))
                    .foregroundStyle(Color.appDynamicHex(light: 0x7C2D12, dark: 0xFEF3C7))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.trailing)
            }
            Text(detail)
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFDBA74))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}
