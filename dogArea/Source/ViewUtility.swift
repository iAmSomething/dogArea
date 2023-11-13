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
    var simpleWalkingTimeInterval: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60 / 1
        if hours == 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    var createdAtTimeDescription: String {
        let date = Date(timeIntervalSince1970: self)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM월dd일HH시mm분SS초"
        let formattedDate = dateFormatter.string(from: date)
        return formattedDate
    }
    var createdAtTimeYYMMDD: String {
        let date = Date(timeIntervalSince1970: self)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY년 MM월 dd일\nHH시 mm분 SS초"
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


import BackgroundTasks
actor registerBackground{
    let base: String = "com.th.dogArea"
    func register() {
    }
}
extension CGFloat {
    static func screenX(by: CGFloat = 100) -> CGFloat {
        screenSize.width * (by / 100)
    }
    static func screenY(by: CGFloat = 100) -> CGFloat {
        screenSize.height * (by / 100)
    }
}
extension CGSize {
    static var screenSize: CGSize {
        UIScreen.main.bounds.size
    }
}
extension PresentationDetent {
    public static var oneThird: PresentationDetent {
        return self.height(screenSize.height * 0.3)
    }
}
struct RenderImageModifier: ViewModifier {
    let rendered: (UIImage) -> ()
    func body(content: Content) -> some View {
        content
            .onAppear {
                DispatchQueue.main.async {
                    let uiImage = content.asUiImage()
                    rendered(uiImage)
                }
            }
    }
}

extension View {
    func renderImage(_ rendered: @escaping (UIImage) -> ()) -> some View {
        self.modifier(RenderImageModifier(rendered: rendered))
    }
    func asUiImage() -> UIImage {
        var uiImage = UIImage(systemName: "exclamationmark.triangle.fill")!
        let controller = UIHostingController(rootView: self)
       
        if let view = controller.view {
            let contentSize = view.intrinsicContentSize
            view.bounds = CGRect(origin: .zero, size: contentSize)
            view.backgroundColor = .clear

            let renderer = UIGraphicsImageRenderer(size: contentSize)
            uiImage = renderer.image { _ in
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
            }
        }
        return uiImage
    }
}
