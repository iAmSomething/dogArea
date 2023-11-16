//
//  ViewUtility.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import Foundation
import SwiftUI
import BackgroundTasks
import CoreLocation

//MARK: - 커스텀탭바 탭 스타일
public struct TabStyle: LabelStyle {
    public func makeBody(configuration: TabStyle.Configuration) -> some View {
        VStack {
            configuration.icon
            configuration.title
        }
    }
}
//MARK: - CLLocation관련 extensions
extension CLLocationCoordinate2D {
    var clLocation : CLLocation {
        CLLocation(latitude: self.latitude, longitude: self.longitude)
    }
}
actor registerBackground{
    let base: String = "com.th.dogArea"
    func register() {
    }
}

//MARK: - ScreenSize
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
public var screenSize: CGSize {
    UIScreen.main.bounds.size
}
//MARK: - sheet 높이 설정
extension PresentationDetent {
    public static var oneThird: PresentationDetent {
        return self.height(screenSize.height * 0.3)
    }
}

//MARK: - View to UIImage
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
    func myCornerRadius(radius: Double) -> some View {
        return self.clipShape(RoundedCornersShape(radius: radius))
    }
}
//MARK: - default empty image
extension UIImage {
    static var emptyImage: UIImage {
        .init(named: "emptyImg")!
    }
}
