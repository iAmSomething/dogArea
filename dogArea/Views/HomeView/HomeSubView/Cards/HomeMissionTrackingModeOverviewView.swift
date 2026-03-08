import SwiftUI

struct HomeMissionTrackingModeOverviewView: View {
    let title: String
    let modes: [HomeMissionTrackingModePresentation]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.appFont(for: .SemiBold, size: 12))
                .foregroundStyle(Color.appTextDarkGray)

            VStack(spacing: 8) {
                ForEach(modes) { mode in
                    modeCard(mode)
                }
            }
        }
        .padding(12)
        .background(Color.appDynamicHex(light: 0xFFFDF8, dark: 0x1E293B))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.quest.tracking.overview")
    }

    /// 추적 방식별 비교 카드 하나를 렌더링합니다.
    /// - Parameter mode: 자동형 또는 직접형 미션의 추적 방식 프레젠테이션입니다.
    /// - Returns: 홈 카드 상단에서 사용자가 즉시 읽을 수 있는 추적 방식 비교 카드입니다.
    @ViewBuilder
    private func modeCard(_ mode: HomeMissionTrackingModePresentation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                HomeMissionTrackingBadgeView(
                    mode: mode,
                    accessibilityIdentifier: "home.quest.tracking.\(mode.id).badge"
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .headline))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    Text(mode.subtitle)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(mode.detailLines.enumerated()), id: \.offset) { index, detail in
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                            .frame(width: 5, height: 5)
                            .padding(.top, 5)
                        Text(detail)
                            .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .body))
                            .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("home.quest.tracking.\(mode.id).detail.\(index)")
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.quest.tracking.\(mode.id)")
    }
}
