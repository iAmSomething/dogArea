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
    static let shareDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter
    }()

    static func dateText(_ createdAt: TimeInterval) -> String {
        shareDateFormatter.string(from: Date(timeIntervalSince1970: createdAt))
    }

    static func pyeongText(areaM2: Double) -> String {
        if areaM2 / 3.3 > 10000 {
            return String(format: "%.1f만 평", areaM2 / 33333)
        }
        return String(format: "%.1f평", areaM2 / 3.3)
    }

    static func build(
        createdAt: TimeInterval,
        duration: TimeInterval,
        areaM2: Double,
        pointCount: Int,
        petName: String?
    ) -> String {
        let dateText = dateText(createdAt)
        let areaText = areaM2.calculatedAreaString
        let pyeongText = pyeongText(areaM2: areaM2)
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

enum WalkShareCardTemplateBuilder {
    private static let canvasSize = CGSize(width: 1080, height: 1080)
    private static let imageCornerRadius: CGFloat = 36
    private static let infoCornerRadius: CGFloat = 32

    static func build(
        baseImage: UIImage,
        createdAt: TimeInterval,
        duration: TimeInterval,
        areaM2: Double,
        pointCount: Int,
        petName: String?
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let dateText = WalkShareSummaryBuilder.dateText(createdAt)
        let areaText = areaM2.calculatedAreaString
        let pyeongText = WalkShareSummaryBuilder.pyeongText(areaM2: areaM2)
        let petText = petName.flatMap { $0.isEmpty ? nil : $0 } ?? "기록 반려견"

        return renderer.image { context in
            let canvasRect = CGRect(origin: .zero, size: canvasSize)
            UIColor(red: 1, green: 0.98, blue: 0.93, alpha: 1).setFill()
            context.fill(canvasRect)

            let mapContainer = CGRect(x: 48, y: 48, width: 984, height: 560)
            let mapPath = UIBezierPath(roundedRect: mapContainer, cornerRadius: imageCornerRadius)
            mapPath.addClip()
            let imageRect = aspectFillRect(imageSize: baseImage.size, container: mapContainer)
            baseImage.draw(in: imageRect)

            UIColor(white: 0, alpha: 0.08).setStroke()
            mapPath.lineWidth = 2
            mapPath.stroke()

            let infoRect = CGRect(x: 48, y: 640, width: 984, height: 332)
            let infoPath = UIBezierPath(roundedRect: infoRect, cornerRadius: infoCornerRadius)
            UIColor.white.setFill()
            infoPath.fill()

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 33, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            let hashtagAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .semibold),
                .foregroundColor: UIColor(red: 0.31, green: 0.31, blue: 0.31, alpha: 1)
            ]

            NSString(string: "DogArea Walk Card").draw(
                in: CGRect(x: infoRect.minX + 36, y: infoRect.minY + 28, width: infoRect.width - 72, height: 56),
                withAttributes: titleAttrs
            )

            let detailText = """
            날짜 \(dateText)
            산책 시간 \(duration.simpleWalkingTimeInterval)
            영역 넓이 \(areaText) (\(pyeongText))
            영역 포인트 \(pointCount)개 · \(petText)
            """
            NSString(string: detailText).draw(
                in: CGRect(x: infoRect.minX + 36, y: infoRect.minY + 108, width: infoRect.width - 72, height: 180),
                withAttributes: bodyAttrs
            )

            NSString(string: "#dogarea  #산책기록").draw(
                in: CGRect(x: infoRect.minX + 36, y: infoRect.minY + 272, width: infoRect.width - 72, height: 40),
                withAttributes: hashtagAttrs
            )
        }
    }

    private static func aspectFillRect(imageSize: CGSize, container: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return container }
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = container.width / container.height
        if imageAspect > containerAspect {
            let targetHeight = container.height
            let targetWidth = targetHeight * imageAspect
            let x = container.midX - targetWidth / 2
            return CGRect(x: x, y: container.minY, width: targetWidth, height: targetHeight)
        }
        let targetWidth = container.width
        let targetHeight = targetWidth / imageAspect
        let y = container.midY - targetHeight / 2
        return CGRect(x: container.minX, y: y, width: targetWidth, height: targetHeight)
    }
}
