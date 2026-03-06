import SwiftUI

struct TerritoryGoalActionHintCardView: View {
    let title: String
    let bodyText: String
    let isFallbackSource: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: isFallbackSource ? "icloud.slash" : "figure.walk")
                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))

            Text(bodyText)
                .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))

            Text(isFallbackSource ? "원격 비교군을 다시 불러오면 기준이 갱신됩니다." : "다음 산책 전에 목표보다 조금 작은 기준도 함께 비교해보세요.")
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    Color.appDynamicHex(light: 0xEAB308, dark: 0xFACC15, alpha: 0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 2])
                )
        )
    }
}
