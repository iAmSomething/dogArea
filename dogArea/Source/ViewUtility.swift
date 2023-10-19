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
