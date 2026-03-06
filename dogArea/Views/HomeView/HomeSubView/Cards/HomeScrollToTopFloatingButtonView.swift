import SwiftUI

struct HomeScrollToTopFloatingButtonView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("맨 위로")
                    .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 8)
        }
        .accessibilityLabel("홈 상단으로 이동")
        .accessibilityHint("스크롤 위치를 맨 위로 이동합니다")
    }
}
