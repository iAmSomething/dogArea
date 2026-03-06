import SwiftUI

struct HomeAreaMilestoneBadgeOverlayView: View {
    let event: AreaMilestoneEvent
    let isVisible: Bool

    /// 목표 임계값을 사용자 표시용 문자열로 변환합니다.
    private var thresholdText: String {
        event.thresholdArea.calculatedAreaString
    }

    var body: some View {
        VStack {
            Spacer().frame(height: 116)

            VStack(spacing: 10) {
                Image(systemName: "rosette")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.appYellow)
                    .accessibilityHidden(true)

                Text("영역 달성 배지 획득")
                    .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xE2E8F0))
                    .multilineTextAlignment(.center)

                Text(event.landmarkName)
                    .font(.appScaledFont(for: .SemiBold, size: 20, relativeTo: .title3))
                    .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFDE68A))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text("누적 \(thresholdText) 돌파")
                    .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .subheadline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.appDynamicHex(light: 0xFDE68A, dark: 0x92400E), lineWidth: 1)
            )
            .scaleEffect(isVisible ? 1.0 : 0.9)
            .opacity(isVisible ? 1.0 : 0.0)

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(isVisible ? 0.2 : 0))
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.landmarkName) 영역 달성 배지를 획득했습니다. 누적 \(thresholdText) 돌파")
    }
}
