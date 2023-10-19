//
//  ViewUtility.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import Foundation
import SwiftUI
public struct TabStyle: LabelStyle {
  public func makeBody(configuration: TabStyle.Configuration) -> some View {
    VStack {
      configuration.icon
      configuration.title
      
    }
  }
}
public var screenSize: CGSize {
  UIScreen.main.bounds.size
}
extension TimeInterval {
  var walkingTimeInterval: String {
      let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
      formatter.unitsStyle = .positional
      formatter.zeroFormattingBehavior = [.pad]

      if let formattedString = formatter.string(from: self) {
          return formattedString.replacingOccurrences(of: " hours", with: "시간")
                                  .replacingOccurrences(of: " minutes", with: "분")
                                  .replacingOccurrences(of: " seconds", with: "초")
      } else {
          return "Invalid time interval"
      }
  }
}
