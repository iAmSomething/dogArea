import SwiftUI

struct TerritoryGoalOverviewCardView: View {
    let currentAreaText: String
    let currentAreaName: String
    let nextGoalNameText: String
    let nextGoalAreaText: String
    let remainingAreaText: String
    let progressRatio: Double
    let progressPercentText: String
    let progressMessageText: String
    let compareDestination: AreaDetailView

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("목표 개요")
                        .font(.appScaledFont(for: .SemiBold, size: 22, relativeTo: .title3))
                        .foregroundStyle(Color.appDynamicHex(light: 0x7C2D12, dark: 0xFED7AA))
                    Text("현재 영역과 다음 목표를 한 번에 비교합니다.")
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
                }

                Spacer(minLength: 0)

                NavigationLink(destination: compareDestination) {
                    Text("비교군 카탈로그 >")
                        .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
                        .frame(minHeight: 44)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                TerritoryGoalMetricBlockView(
                    title: "현재 영역",
                    value: currentAreaText,
                    detail: currentAreaName
                )
                TerritoryGoalMetricBlockView(
                    title: "다음 목표",
                    value: nextGoalNameText,
                    detail: nextGoalAreaText
                )
            }

            HStack(alignment: .bottom) {
                Text("남은 면적: \(remainingAreaText)")
                    .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFED7AA))
                Spacer()
                Text(progressPercentText)
                    .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0xF59E0B, dark: 0xFACC15))
            }

            TerritoryGoalProgressBarView(progress: progressRatio)
                .accessibilityLabel("목표 진행률")
                .accessibilityValue(progressPercentText)

            Text(progressMessageText)
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

private struct TerritoryGoalMetricBlockView: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
            Text(value)
                .font(.appScaledFont(for: .SemiBold, size: 24, relativeTo: .title3))
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

private struct TerritoryGoalProgressBarView: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(1.0, max(0.0, progress))
            let width = max(12, proxy.size.width * clamped)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appDynamicHex(light: 0xFED7AA, dark: 0x7C2D12, alpha: 0.35))
                Capsule()
                    .fill(Color.appDynamicHex(light: 0xEAB308, dark: 0xFACC15))
                    .frame(width: width)
            }
        }
        .frame(height: 8)
    }
}
