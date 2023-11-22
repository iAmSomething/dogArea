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
    static let appRed: Color = Color(red: 1, green: 0.43, blue: 0.38)
    static let appYellow: Color = Color(red: 0.97, green: 0.82, blue: 0.38)
    static let appYellowPale: Color = Color(red: 0.95, green: 0.91, blue: 0.62)
    static let appGreen: Color = Color(red: 0.6, green: 0.85, blue: 0.67)
    static let appTextLightGray: Color = Color(red: 0.85, green: 0.85, blue: 0.85)
    static let appTextDarkGray: Color = Color(red: 0.59, green: 0.59, blue: 0.59)
    static let appPinkYello: Color = Color(red: 1, green: 238.0/255.0, blue: 204.0/255.0)
    static let appPeach: Color = Color(red: 1, green: 221.0/255, blue: 204.0/255.0)
    static let appPink: Color = Color(red: 1, green: 204.0/255, blue: 204.0/255.0)
    static let appHotPink: Color = Color(red: 1, green: 187.0/255, blue: 204.0/255.0)
    static func appColor(type: appColorType, scheme: ColorScheme = .light) -> Color {
        return scheme == .dark ? type.darkColor : type.color
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
                Color(red: 1, green: 0.43, blue: 0.38)
            case .appYellow:
                Color(red: 0.97, green: 0.82, blue: 0.38)
            case .appYellowPale:
                Color(red: 0.95, green: 0.91, blue: 0.62)
            case .appGreen:
                Color(red: 0.6, green: 0.85, blue: 0.67)
            case .appTextLightGray:
                Color(red: 0.85, green: 0.85, blue: 0.85)
            case .appTextDarkGray:
                Color(red: 0.59, green: 0.59, blue: 0.59)
            case .appTextBlack:
                Color(red: 0, green:0, blue: 0)
            case .appPinkYello:
                Color(red: 1, green: 238.0/255.0, blue: 204.0/255.0)
            case .appPeach:
                Color(red: 1, green: 221.0/255, blue: 204.0/255.0)
            case .appPink:
                Color(red: 1, green: 204.0/255, blue: 204.0/255.0)
            case .appHotPink:
                Color(red: 1, green: 187.0/255, blue: 204.0/255.0)
            }
        }
        var darkColor: Color {
            switch self{
            case .appRed:
                Color(red: 1, green: 0.34, blue: 0.2)
            case .appYellow:
                Color(red: 0.98, green: 0.86, blue: 0.43)
            case .appYellowPale:
                Color(red: 0.97, green: 0.94, blue: 0.76)
            case .appGreen:
                Color(red: 0.69, green: 0.86, blue: 0.75)
            case .appTextLightGray:
                Color(red: 0.96, green: 0.96, blue: 0.96)
            case .appTextDarkGray:
                Color(red: 0.83, green: 0.83, blue: 0.83)
            case .appTextBlack:
                Color(red: 1, green:1, blue: 1)
            case .appPinkYello:
                Color(red: 1, green: 238.0/255.0, blue: 204.0/255.0)
            case .appPeach:
                Color(red: 1, green: 221.0/255, blue: 204.0/255.0)
            case .appPink:
                Color(red: 1, green: 204.0/255, blue: 204.0/255.0)
            case .appHotPink:
                Color(red: 1, green: 187.0/255, blue: 204.0/255.0)
            }
        }
    }
}
extension UIColor {
    static let appYelloww: UIColor = UIColor(red: 0.97, green: 0.82, blue: 0.38, alpha: 1)
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
