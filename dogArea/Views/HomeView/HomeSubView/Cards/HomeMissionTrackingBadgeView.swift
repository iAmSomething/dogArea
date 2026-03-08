import SwiftUI

struct HomeMissionTrackingBadgeView: View {
    let mode: HomeMissionTrackingModePresentation
    let accessibilityIdentifier: String?

    /// 홈 미션 추적 방식 배지를 생성합니다.
    /// - Parameters:
    ///   - mode: 자동 기록형 또는 직접 체크형을 설명하는 추적 방식 프레젠테이션입니다.
    ///   - accessibilityIdentifier: UI 테스트에서 배지를 식별할 때 사용할 접근성 식별자입니다.
    init(
        mode: HomeMissionTrackingModePresentation,
        accessibilityIdentifier: String? = nil
    ) {
        self.mode = mode
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    private var tintColor: Color {
        switch mode.kind {
        case .automatic:
            return Color.appDynamicHex(light: 0x3B82F6, dark: 0x93C5FD)
        case .manual:
            return Color.appYellow
        }
    }

    private var backgroundColor: Color {
        switch mode.kind {
        case .automatic:
            return Color.appDynamicHex(light: 0xEFF6FF, dark: 0x1E3A8A, alpha: 0.34)
        case .manual:
            return Color.appYellowPale.opacity(0.9)
        }
    }

    @ViewBuilder
    var body: some View {
        if let accessibilityIdentifier {
            badgeContent
                .accessibilityIdentifier(accessibilityIdentifier)
        } else {
            badgeContent
        }
    }

    private var badgeContent: some View {
        HStack(spacing: 6) {
            Image(systemName: mode.iconSystemName)
                .font(.system(size: 11, weight: .semibold))
            Text(mode.badgeText)
                .font(.appFont(for: .SemiBold, size: 11))
        }
        .accessibilityElement(children: .combine)
        .foregroundStyle(tintColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .clipShape(Capsule())
    }
}
