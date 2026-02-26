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
import UIKit

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
        var uiImage = UIImage(systemName: "exclamationmark.triangle.fill") ?? UIImage()
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
        .init(named: "emptyImg") ?? UIImage()
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var completion: UIActivityViewController.CompletionWithItemsHandler?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = completion
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum WalkShareSummaryBuilder {
    private static let shareDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter
    }()

    static func build(
        createdAt: TimeInterval,
        duration: TimeInterval,
        areaM2: Double,
        pointCount: Int,
        petName: String?
    ) -> String {
        let dateText = shareDateFormatter.string(from: Date(timeIntervalSince1970: createdAt))
        let areaText = areaM2.calculatedAreaString
        let pyeongText: String
        if areaM2 / 3.3 > 10000 {
            pyeongText = String(format: "%.1f만 평", areaM2 / 33333)
        } else {
            pyeongText = String(format: "%.1f평", areaM2 / 3.3)
        }
        let petLine = petName.flatMap { $0.isEmpty ? nil : "\n반려견: \($0)" } ?? ""
        return """
        DogArea 산책 기록
        날짜: \(dateText)
        산책 시간: \(duration.simpleWalkingTimeInterval)
        영역 넓이: \(areaText) (\(pyeongText))
        영역 포인트: \(pointCount)개\(petLine)
        """
    }
}
