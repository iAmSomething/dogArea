import SwiftUI

struct AreaDetailSummaryCardView: View {
    let currentAreaText: String
    let currentAreaName: String
    let nextGoalNameText: String
    let nextGoalAreaText: String
    let remainingAreaText: String
    let featuredSummaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("비교군 요약")
                .font(.appScaledFont(for: .SemiBold, size: 20, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x7C2D12, dark: 0xFED7AA))

            HStack(alignment: .top, spacing: 16) {
                AreaDetailMetricView(title: "현재 영역", value: currentAreaText, detail: currentAreaName)
                AreaDetailMetricView(title: "다음 목표", value: nextGoalNameText, detail: nextGoalAreaText)
            }

            HStack(alignment: .center) {
                Text("남은 면적")
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                Spacer()
                Text(remainingAreaText)
                    .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                    .foregroundStyle(Color.appDynamicHex(light: 0xF59E0B, dark: 0xFACC15))
            }

            Text(featuredSummaryText)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
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

private struct AreaDetailMetricView: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
            Text(value)
                .font(.appScaledFont(for: .SemiBold, size: 22, relativeTo: .title3))
                .foregroundStyle(Color.appDynamicHex(light: 0x7C2D12, dark: 0xFEF3C7))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            Text(detail)
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFDBA74))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
