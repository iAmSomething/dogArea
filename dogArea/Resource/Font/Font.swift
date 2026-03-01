//
//  Font.swift
//  dogArea
//
//  Created by 김태훈 on 11/7/23.
//

import Foundation
import SwiftUI
extension Font {
  // ExtraBold
  static let extraBold28: Font = .custom(FontType.ExtraBold.rawValue, size: 28)
  // Bold
  static let bold28: Font = .custom(FontType.Bold.rawValue, size: 28)
  static let bold24: Font = .custom(FontType.Bold.rawValue, size: 24)
  static let bold18: Font = .custom(FontType.Bold.rawValue, size: 18)
  static let bold14: Font = .custom(FontType.Bold.rawValue, size: 14)
  
  // SemiBold
  static let semibold16: Font = .custom(FontType.SemiBold.rawValue, size: 16)
  
  // Medium
  static let medium18: Font = .custom(FontType.Medium.rawValue, size: 18)
  static let medium16: Font = .custom(FontType.Medium.rawValue, size: 16)
  
  // Regular
  static let regular12: Font = .custom(FontType.Regular.rawValue, size: 12)

  static let regular14: Font = .custom(FontType.Regular.rawValue, size: 14)
  static let regular16: Font = .custom(FontType.Regular.rawValue, size: 16)
  static let regular18: Font = .custom(FontType.Regular.rawValue, size: 18)

  
  //appFont
  static func appFont(for type : FontType, size: CGFloat) -> Font? {
    self.custom(type.rawValue, size: size)
  }

  /// Dynamic Type 크기에 맞춰 스케일되는 앱 전용 폰트를 반환합니다.
  /// - Parameters:
  ///   - type: 적용할 폰트 패밀리 타입입니다.
  ///   - size: 기준 폰트 크기입니다.
  ///   - textStyle: Dynamic Type 스케일의 기준 텍스트 스타일입니다.
  /// - Returns: 접근성 글꼴 크기에 반응하는 `Font`입니다.
  static func appScaledFont(for type: FontType, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
    self.custom(type.rawValue, size: size, relativeTo: textStyle)
  }
}
enum FontType: String {
  case Black = "Pretendard-Black"
  case ExtraBold = "Pretendard-ExtraBold"
  case Bold = "Pretendard-Bold"
  case SemiBold = "Pretendard-SemiBold"
  case Medium = "Pretendard-Medium"
  case Regular = "Pretendard-Regular"
  case Light = "Pretendard-Light"
  case ExtraLight = "Pretendard-ExtraLight"
  case Thin = "Pretendard-Thin"
}
