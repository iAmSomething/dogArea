import SwiftUI

struct HomeGoalTrackerCardView: View {
    let areaReferenceSourceLabel: String
    let featuredAreaCount: Int
    let currentAreaText: String
    let currentAreaName: String
    let nextGoalNameText: String
    let nextGoalAreaText: String
    let remainingAreaText: String
    let progressRatio: Double
    let onOpenDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("영역 목표 트래커")
                        .font(.appScaledFont(for: .SemiBold, size: 28, relativeTo: .title3))
                        .foregroundStyle(Color.appDynamicHex(light: 0x7C2D12, dark: 0xFED7AA))
                    Text("비교 기준: \(areaReferenceSourceLabel) · 우선 추천 \(featuredAreaCount)개")
                        .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
                }
                Spacer(minLength: 0)
                Button(action: onOpenDetail) {
                    Text("목표 상세 보기 >")
                        .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
                        .padding(.horizontal, 6)
                        .frame(minHeight: 44, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.goalTracker.more")
            }

            HStack(alignment: .top, spacing: 16) {
                HomeGoalMetricColumnView(
                    title: "현재 영역",
                    value: currentAreaText,
                    detail: currentAreaName
                )
                HomeGoalMetricColumnView(
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
                Text("\(Int(progressRatio * 100))%")
                    .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0xF59E0B, dark: 0xFDE68A))
            }

            ProgressView(value: progressRatio)
                .tint(Color.appDynamicHex(light: 0xEAB308, dark: 0xFACC15))
                .scaleEffect(x: 1, y: 1.25, anchor: .center)
                .accessibilityLabel("목표 진행률")
                .accessibilityValue("\(Int(progressRatio * 100)) 퍼센트")

            Text("목표까지 아주 조금 남았어요! 한 번만 더 산책해볼까요?")
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
                .lineLimit(2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x431407, alpha: 0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xFED7AA, dark: 0x7C2D12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}
