//
//  Color.swift
//  dogArea
//
//  Created by 김태훈 on 11/7/23.
//

import Foundation
import SwiftUI
import UIKit

extension Color {
    // MARK: - Brand / Semantic Tokens
    static let appRed: Color = Color(red: 0.90, green: 0.32, blue: 0.27)
    static let appYellow: Color = Color(red: 0.93, green: 0.70, blue: 0.19)
    static let appYellowPale: Color = Color(red: 0.98, green: 0.95, blue: 0.87)
    static let appGreen: Color = Color(red: 0.27, green: 0.67, blue: 0.50)
    static let appTextLightGray: Color = Color(red: 0.82, green: 0.84, blue: 0.87)
    static let appTextDarkGray: Color = Color(red: 0.38, green: 0.42, blue: 0.49)
    static let appPinkYello: Color = Color(red: 0.98, green: 0.94, blue: 0.84)
    static let appPeach: Color = Color(red: 0.98, green: 0.87, blue: 0.79)
    static let appPink: Color = Color(red: 0.96, green: 0.81, blue: 0.76)
    static let appHotPink: Color = Color(red: 0.90, green: 0.49, blue: 0.56)

    static let appBackground: Color = Color(red: 0.96, green: 0.95, blue: 0.90)
    static let appSurface: Color = Color.white
    static let appInk: Color = Color(red: 0.11, green: 0.13, blue: 0.17)
    static let appTabScaffoldBackground: Color = Color.appDynamicHex(
        light: 0xFAFAF8,
        dark: 0x1E293B
    )

    /// 16진수 RGB 값을 SwiftUI 색상으로 변환합니다.
    /// - Parameters:
    ///   - hex: `0xRRGGBB` 형식의 색상 값입니다.
    ///   - alpha: 알파(투명도) 값입니다.
    /// - Returns: 지정한 색상 값을 가지는 `Color`입니다.
    static func appHex(_ hex: UInt, alpha: Double = 1.0) -> Color {
        Color(uiColor: UIColor(appHex: hex, alpha: CGFloat(alpha)))
    }

    /// 라이트/다크 모드에 따라 서로 다른 16진수 색상을 적용합니다.
    /// - Parameters:
    ///   - light: 라이트 모드의 `0xRRGGBB` 색상 값입니다.
    ///   - dark: 다크 모드의 `0xRRGGBB` 색상 값입니다.
    ///   - alpha: 알파(투명도) 값입니다.
    /// - Returns: 인터페이스 스타일에 반응하는 동적 `Color`입니다.
    static func appDynamicHex(light: UInt, dark: UInt, alpha: Double = 1.0) -> Color {
        Color(uiColor: UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(appHex: hex, alpha: CGFloat(alpha))
        })
    }

    static func appColor(type: appColorType, scheme: ColorScheme = .light) -> Color {
        scheme == .dark ? type.darkColor : type.color
    }
}

extension Color {
    enum appColorType {
        case appRed
        case appYellow
        case appYellowPale
        case appGreen
        case appTextLightGray
        case appTextDarkGray
        case appTextBlack
        case appPinkYello
        case appPeach
        case appPink
        case appHotPink
        var color: Color {
            switch self {
            case .appRed:
                Color.appRed
            case .appYellow:
                Color.appYellow
            case .appYellowPale:
                Color.appYellowPale
            case .appGreen:
                Color.appGreen
            case .appTextLightGray:
                Color.appTextLightGray
            case .appTextDarkGray:
                Color.appTextDarkGray
            case .appTextBlack:
                Color.appInk
            case .appPinkYello:
                Color.appPinkYello
            case .appPeach:
                Color.appPeach
            case .appPink:
                Color.appPink
            case .appHotPink:
                Color.appHotPink
            }
        }
        var darkColor: Color {
            switch self{
            case .appRed:
                Color(red: 0.93, green: 0.44, blue: 0.39)
            case .appYellow:
                Color(red: 0.95, green: 0.77, blue: 0.32)
            case .appYellowPale:
                Color(red: 0.29, green: 0.27, blue: 0.22)
            case .appGreen:
                Color(red: 0.40, green: 0.74, blue: 0.57)
            case .appTextLightGray:
                Color(red: 0.70, green: 0.72, blue: 0.76)
            case .appTextDarkGray:
                Color(red: 0.85, green: 0.87, blue: 0.90)
            case .appTextBlack:
                Color(red: 0.95, green: 0.96, blue: 0.98)
            case .appPinkYello:
                Color(red: 0.34, green: 0.30, blue: 0.23)
            case .appPeach:
                Color(red: 0.44, green: 0.34, blue: 0.30)
            case .appPink:
                Color(red: 0.45, green: 0.31, blue: 0.30)
            case .appHotPink:
                Color(red: 0.56, green: 0.30, blue: 0.36)
            }
        }
    }
}

extension UIColor {
    static let appYelloww: UIColor = UIColor(red: 0.93, green: 0.70, blue: 0.19, alpha: 1)

    /// 16진수 RGB 값을 `UIColor`로 변환해 초기화합니다.
    /// - Parameters:
    ///   - appHex: `0xRRGGBB` 형식의 색상 값입니다.
    ///   - alpha: 알파(투명도) 값입니다.
    convenience init(appHex: UInt, alpha: CGFloat = 1.0) {
        let red = CGFloat((appHex >> 16) & 0xFF) / 255.0
        let green = CGFloat((appHex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(appHex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

enum AppButtonRole {
    case primary
    case secondary
    case neutral
    case destructive

    var backgroundColor: Color {
        switch self {
        case .primary: return Color.appInk
        case .secondary: return Color.appYellow
        case .neutral: return Color.appSurface
        case .destructive: return Color.appRed
        }
    }

    var foregroundColor: Color {
        switch self {
        case .primary, .destructive: return .white
        case .secondary: return Color.appInk
        case .neutral: return Color.appInk
        }
    }

    var borderColor: Color {
        switch self {
        case .neutral: return Color.appTextLightGray.opacity(0.85)
        default: return .clear
        }
    }
}

struct AppFilledButtonStyle: ButtonStyle {
    let role: AppButtonRole
    var fillsWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appFont(for: .SemiBold, size: 15))
            .foregroundStyle(role.foregroundColor)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .padding(.vertical, 12)
            .padding(.horizontal, fillsWidth ? 0 : 12)
            .background(role.backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(role.borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.93 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.appTextLightGray.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 6)
    }
}

struct AppInputFieldStyle: ViewModifier {
    let validity: Bool?

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var borderColor: Color {
        if let validity {
            return validity ? Color.appGreen.opacity(0.75) : Color.appRed.opacity(0.75)
        }
        return Color.appTextLightGray.opacity(0.7)
    }
}

struct AppPillStyle: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .font(.appFont(for: .SemiBold, size: 12))
            .foregroundStyle(isActive ? Color.appInk : Color.appTextDarkGray)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color.appYellow : Color.appYellowPale)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension View {
    /// 공통 카드 표면 스타일을 적용합니다.
    func appCardSurface() -> some View {
        modifier(AppCardSurface())
    }

    /// 공통 입력 필드 스타일을 적용합니다.
    func appInputField(validity: Bool? = nil) -> some View {
        modifier(AppInputFieldStyle(validity: validity))
    }

    /// 공통 칩(필터/토글) 스타일을 적용합니다.
    func appPill(isActive: Bool) -> some View {
        modifier(AppPillStyle(isActive: isActive))
    }
}
// 색 보기
struct ColorListView: View {
    var body: some View {
        NavigationStack {
            List {
                Rectangle().foregroundStyle(Color.appRed)
                Rectangle().foregroundStyle(Color.appYellow)
                Rectangle().foregroundStyle(Color.appYellowPale)
                Rectangle().foregroundStyle(Color.appGreen)
                Rectangle().foregroundStyle(Color.appTextLightGray)
                Rectangle().foregroundStyle(Color.appTextDarkGray)
                Rectangle().foregroundStyle(Color.appPinkYello)
                Rectangle().foregroundStyle(Color.appPeach)
                Rectangle().foregroundStyle(Color.appPink)
                Rectangle().foregroundStyle(Color.appHotPink)
            }
        }
    }
}
#Preview {
    ColorListView()
}
