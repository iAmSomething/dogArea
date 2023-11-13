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
