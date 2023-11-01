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
    let hours = Int(self) / 3600
    let minutes = (Int(self) % 3600) / 60
    let seconds = Int(self) % 60 / 1
    
    return String(format: "%02d시간 %02d분 %02d초", hours, minutes, seconds)

  }
  var createdAtTimeDescription: String {
    let date = Date(timeIntervalSince1970: self)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MM월dd일HH시mm분SS초"
    let formattedDate = dateFormatter.string(from: date)
    return formattedDate
  }
  
}
import CoreLocation
extension CLLocationCoordinate2D {
  var clLocation : CLLocation {
    CLLocation(latitude: self.latitude, longitude: self.longitude)
  }
}
extension Font {
  public static func customFont(size: CGFloat = 13) -> Font {
    Font.custom("KCC-Ganpan.otf", size: size)
  }
}


import BackgroundTasks
actor registerBackground{
  let base: String = "com.th.dogArea"
  func register() {
  }
}
