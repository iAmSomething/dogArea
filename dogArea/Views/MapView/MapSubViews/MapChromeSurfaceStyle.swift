import SwiftUI

enum MapChromeLayoutMetrics {
    static let horizontalPadding: CGFloat = 16
    static let topSectionSpacing: CGFloat = 10
    static let pillSpacing: CGFloat = 8
    static let surfaceCornerRadius: CGFloat = 20
    static let secondaryCornerRadius: CGFloat = 14
    static let iconButtonSize: CGFloat = 48
    static let primaryFloatingButtonSize: CGFloat = 60
}

enum MapChromePillTone {
    case neutral
    case accent
    case warning
    case success
}

enum MapChromePalette {
    static let surfaceBackground = Color.appDynamicHex(light: 0xFFFFFF, dark: 0x243244, alpha: 0.94)
    static let elevatedSurfaceBackground = Color.appDynamicHex(light: 0xFFF7E7, dark: 0x2E2618, alpha: 0.96)
    static let surfaceBorder = Color.appDynamicHex(light: 0xD8DEE7, dark: 0x475569, alpha: 0.92)
    static let primaryText = Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC)
    static let secondaryText = Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1)
    static let neutralPillBackground = Color.appDynamicHex(light: 0xFFFFFF, dark: 0x334155, alpha: 0.92)
    static let accentPillBackground = Color.appDynamicHex(light: 0xFEF3C7, dark: 0x3B2F16, alpha: 0.96)
    static let warningPillBackground = Color.appDynamicHex(light: 0xFDE68A, dark: 0x4A3513, alpha: 0.96)
    static let successPillBackground = Color.appDynamicHex(light: 0xDCFCE7, dark: 0x163226, alpha: 0.96)
}

private struct MapChromeSurfaceModifier: ViewModifier {
    let emphasized: Bool

    func body(content: Content) -> some View {
        content
            .background(emphasized ? MapChromePalette.elevatedSurfaceBackground : MapChromePalette.surfaceBackground)
            .overlay(
                RoundedRectangle(cornerRadius: MapChromeLayoutMetrics.surfaceCornerRadius)
                    .stroke(MapChromePalette.surfaceBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: MapChromeLayoutMetrics.surfaceCornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 8)
    }
}

private struct MapChromePillModifier: ViewModifier {
    let tone: MapChromePillTone

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: MapChromeLayoutMetrics.secondaryCornerRadius)
                    .stroke(MapChromePalette.surfaceBorder.opacity(0.82), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: MapChromeLayoutMetrics.secondaryCornerRadius, style: .continuous))
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral:
            MapChromePalette.neutralPillBackground
        case .accent:
            MapChromePalette.accentPillBackground
        case .warning:
            MapChromePalette.warningPillBackground
        case .success:
            MapChromePalette.successPillBackground
        }
    }
}

struct MapChromeIconButton: View {
    let systemImageName: String
    let accessibilityIdentifier: String
    let accessibilityLabel: String
    let accessibilityHint: String?
    let emphasized: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImageName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MapChromePalette.primaryText)
                .frame(width: MapChromeLayoutMetrics.iconButtonSize, height: MapChromeLayoutMetrics.iconButtonSize)
                .background(emphasized ? Color.appYellow : MapChromePalette.surfaceBackground)
                .overlay(
                    Circle()
                        .stroke(MapChromePalette.surfaceBorder, lineWidth: 1)
                )
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
    }
}

extension View {
    /// 지도 크롬 전용 surface 배경, 테두리, 그림자 스타일을 적용합니다.
    /// - Parameter emphasized: 강조 surface 여부입니다. `true`면 노란 톤을 섞은 강조 배경을 사용합니다.
    /// - Returns: 지도 크롬 surface 스타일이 적용된 뷰입니다.
    func mapChromeSurface(emphasized: Bool = false) -> some View {
        modifier(MapChromeSurfaceModifier(emphasized: emphasized))
    }

    /// 지도 크롬에서 쓰는 badge/pill 형태 배경을 적용합니다.
    /// - Parameter tone: pill의 강조 톤입니다.
    /// - Returns: 지도 pill surface 스타일이 적용된 뷰입니다.
    func mapChromePill(_ tone: MapChromePillTone = .neutral) -> some View {
        modifier(MapChromePillModifier(tone: tone))
    }
}
