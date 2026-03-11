import MessageUI
import SwiftUI

/// 메일 작성 시트의 전송 결과를 SwiftUI에서 다루기 쉬운 형태로 정규화합니다.
enum SettingsMailComposeResult: Equatable {
    case sent
    case saved
    case cancelled
    case failed(String)
}

/// iOS 메일 작성기를 SwiftUI sheet로 감싸는 래퍼입니다.
struct SettingsMailComposeSheet: UIViewControllerRepresentable {
    let draft: SettingsPrivacyDeletionRequestDraft
    let onFinish: (SettingsMailComposeResult) -> Void

    /// 현재 기기에서 in-app 메일 작성기를 사용할 수 있는지 반환합니다.
    /// - Returns: Mail 계정이 구성돼 있어 `MFMailComposeViewController`를 바로 띄울 수 있으면 `true`입니다.
    static func canSendMail() -> Bool {
        MFMailComposeViewController.canSendMail()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([draft.recipientEmail])
        controller.setSubject(draft.subject)
        controller.setMessageBody(draft.body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onFinish: (SettingsMailComposeResult) -> Void

        /// 메일 작성 시트 delegate를 구성합니다.
        /// - Parameter onFinish: 메일 작성 종료 결과를 SwiftUI 계층으로 전달할 콜백입니다.
        init(onFinish: @escaping (SettingsMailComposeResult) -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
            if let error {
                onFinish(.failed(error.localizedDescription))
                return
            }

            switch result {
            case .sent:
                onFinish(.sent)
            case .saved:
                onFinish(.saved)
            case .cancelled:
                onFinish(.cancelled)
            case .failed:
                onFinish(.failed("메일 전송을 완료하지 못했어요."))
            @unknown default:
                onFinish(.failed("메일 전송 결과를 확인하지 못했어요."))
            }
        }
    }
}
