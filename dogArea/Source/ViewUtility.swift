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

enum ActivitySharePresentationResult: Equatable {
    case presented
    case completed
    case cancelled
    case failed(reason: String)
}

private enum ActivitySharePresentationError: LocalizedError {
    case emptyItems
    case hostUnavailable
    case hostBusy

    var errorDescription: String? {
        switch self {
        case .emptyItems:
            return "공유할 항목이 비어 있습니다."
        case .hostUnavailable:
            return "공유 시트를 표시할 화면을 찾지 못했습니다."
        case .hostBusy:
            return "이미 다른 모달이 표시 중입니다."
        }
    }
}

final class ActivityShareHostViewController: UIViewController {
    /// 시스템 공유 시트를 띄우기 위한 최소 호스트 뷰를 생성합니다.
    /// - Returns: 투명하고 숨김 처리된 루트 뷰입니다.
    override func loadView() {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isHidden = true
        self.view = view
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let items: [Any]
    var onEvent: (ActivitySharePresentationResult) -> Void = { _ in }

    /// SwiftUI 바인딩과 결과 콜백을 보관할 코디네이터를 생성합니다.
    /// - Returns: 공유 시트 수명주기를 관리하는 코디네이터입니다.
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onEvent: onEvent)
    }

    /// 시스템 공유 시트를 직접 표시할 UIKit 호스트 컨트롤러를 생성합니다.
    /// - Parameter context: SwiftUI representable 생성 컨텍스트입니다.
    /// - Returns: 공유 presenter의 기준점이 되는 호스트 컨트롤러입니다.
    func makeUIViewController(context: Context) -> ActivityShareHostViewController {
        ActivityShareHostViewController()
    }

    /// SwiftUI 상태 변경에 맞춰 공유 시트 presenter를 열거나 정리합니다.
    /// - Parameters:
    ///   - uiViewController: 공유 시트를 표시할 현재 호스트 컨트롤러입니다.
    ///   - context: representable 업데이트 컨텍스트입니다.
    func updateUIViewController(_ uiViewController: ActivityShareHostViewController, context: Context) {
        context.coordinator.isPresented = $isPresented
        context.coordinator.onEvent = onEvent
        if isPresented == false {
            context.coordinator.resetIfIdle()
            return
        }
        context.coordinator.presentIfNeeded(from: uiViewController, items: items)
    }

    final class Coordinator {
        var isPresented: Binding<Bool>
        var onEvent: (ActivitySharePresentationResult) -> Void
        private var isPresentingController = false

        /// 공유 presenter 코디네이터를 초기화합니다.
        /// - Parameters:
        ///   - isPresented: SwiftUI 공유 시트 표시 상태 바인딩입니다.
        ///   - onEvent: presenter 결과를 상위 뷰에 전달하는 콜백입니다.
        init(
            isPresented: Binding<Bool>,
            onEvent: @escaping (ActivitySharePresentationResult) -> Void
        ) {
            self.isPresented = isPresented
            self.onEvent = onEvent
        }

        /// 공유 시트가 아직 열리지 않은 경우에만 시스템 share presenter를 표시합니다.
        /// - Parameters:
        ///   - host: `UIActivityViewController`를 표시할 호스트 컨트롤러입니다.
        ///   - items: 공유 시트에 전달할 activity item 배열입니다.
        func presentIfNeeded(from host: UIViewController, items: [Any]) {
            guard isPresentingController == false else { return }
            guard items.isEmpty == false else {
                finish(with: .failed(reason: ActivitySharePresentationError.emptyItems.localizedDescription))
                return
            }
            if ProcessInfo.processInfo.arguments.contains("-UITest.UseShareSheetStub") {
                isPresentingController = true
                onEvent(.presented)
                return
            }
            attemptPresentation(from: host, items: items, attempt: 0)
        }

        /// 시스템 공유 시트를 실제 호스트 컨트롤러 위에 직접 표시합니다.
        /// - Parameters:
        ///   - host: share presenter를 올릴 현재 화면 컨트롤러입니다.
        ///   - items: 공유할 activity item 배열입니다.
        ///   - attempt: 호스트가 window에 연결되길 기다리는 재시도 횟수입니다.
        private func attemptPresentation(from host: UIViewController?, items: [Any], attempt: Int) {
            guard let host else {
                finish(with: .failed(reason: ActivitySharePresentationError.hostUnavailable.localizedDescription))
                return
            }
            guard let presenter = resolvedPresentationHost(from: host) else {
                finish(with: .failed(reason: ActivitySharePresentationError.hostUnavailable.localizedDescription))
                return
            }
            guard presenter.viewIfLoaded?.window != nil else {
                guard attempt < 3 else {
                    finish(with: .failed(reason: ActivitySharePresentationError.hostUnavailable.localizedDescription))
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self, weak host] in
                    self?.attemptPresentation(from: host, items: items, attempt: attempt + 1)
                }
                return
            }
            guard presenter.presentedViewController == nil else {
                finish(with: .failed(reason: ActivitySharePresentationError.hostBusy.localizedDescription))
                return
            }

            let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
            controller.popoverPresentationController?.sourceView = presenter.view
            controller.popoverPresentationController?.sourceRect = presenter.view.bounds
            controller.completionWithItemsHandler = { [weak self] _, completed, _, error in
                DispatchQueue.main.async {
                    if let error {
                        self?.finish(with: .failed(reason: error.localizedDescription))
                    } else if completed {
                        self?.finish(with: .completed)
                    } else {
                        self?.finish(with: .cancelled)
                    }
                }
            }

            isPresentingController = true
            onEvent(.presented)
            presenter.present(controller, animated: true)
        }

        /// 현재 foreground window에 연결된 최상단 presenter를 찾아 시스템 공유 시트 기준점으로 사용합니다.
        /// - Parameter host: representable이 제공한 기본 호스트 컨트롤러입니다.
        /// - Returns: 공유 시트를 올릴 수 있는 최상단 UIKit presenter입니다.
        private func resolvedPresentationHost(from host: UIViewController) -> UIViewController? {
            if let window = host.viewIfLoaded?.window,
               let root = window.rootViewController {
                return topMostPresenter(startingFrom: root)
            }

            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let candidateWindows = scenes.flatMap(\.windows)
            if let keyWindow = candidateWindows.first(where: \.isKeyWindow),
               let root = keyWindow.rootViewController {
                return topMostPresenter(startingFrom: root)
            }
            if let visibleWindow = candidateWindows.first(where: { $0.isHidden == false }),
               let root = visibleWindow.rootViewController {
                return topMostPresenter(startingFrom: root)
            }
            return nil
        }

        /// 네비게이션/탭/모달을 따라 실제 프레젠테이션이 가능한 최상단 컨트롤러를 탐색합니다.
        /// - Parameter controller: 탐색 시작 기준 컨트롤러입니다.
        /// - Returns: 현재 화면 계층에서 가장 위에 있는 presenter 후보입니다.
        private func topMostPresenter(startingFrom controller: UIViewController) -> UIViewController {
            if let navigationController = controller as? UINavigationController,
               let visible = navigationController.visibleViewController {
                return topMostPresenter(startingFrom: visible)
            }
            if let tabBarController = controller as? UITabBarController,
               let selected = tabBarController.selectedViewController {
                return topMostPresenter(startingFrom: selected)
            }
            if let presented = controller.presentedViewController {
                return topMostPresenter(startingFrom: presented)
            }
            return controller
        }

        /// 공유 플로우 종료 이벤트를 상태 바인딩과 사용자 피드백 이벤트로 정리합니다.
        /// - Parameter result: presenter 종료 결과입니다.
        private func finish(with result: ActivitySharePresentationResult) {
            isPresentingController = false
            isPresented.wrappedValue = false
            onEvent(result)
        }

        /// 현재 presenter가 열려 있지 않은 경우 내부 상태를 초기화합니다.
        func resetIfIdle() {
            guard isPresentingController == false else { return }
        }
    }
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
