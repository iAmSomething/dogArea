//
//  CustomAlertConfigure.swift
//  dogArea
//
//  Created by 김태훈 on 10/17/23.
//

import CoreGraphics
import Foundation

enum AlertActionSemanticRole: String, Equatable {
    case primary
    case secondary
    case destructive
}

enum AlertButtonLayout: Equatable {
    case adaptive
    case horizontal
    case vertical
}

enum AlertSurfaceTone: Equatable {
    case neutral
    case caution
    case danger
}

struct AlertButtonDescriptor: Equatable, Identifiable {
    let id: String
    let title: String
    let role: AlertActionSemanticRole

    /// 접근성 식별자와 버튼 의미 계층을 포함한 알럿 버튼 설명자를 생성합니다.
    /// - Parameters:
    ///   - id: UI 테스트와 식별자 매핑에 사용할 고유 문자열입니다.
    ///   - title: 버튼에 표시할 사용자 문구입니다.
    ///   - role: 버튼의 의미 계층(주 행동/보조 행동/파괴적 행동)입니다.
    init(id: String, title: String, role: AlertActionSemanticRole) {
        self.id = id
        self.title = title
        self.role = role
    }
}

enum AlertActionType {
    typealias AlertActionHandler = () -> Void

    case custom(AlertModel, AlertActionHandler, AlertActionHandler)
    case customThreeButton(AlertModel, AlertActionHandler, AlertActionHandler, AlertActionHandler)
    case loggedOut
    case authRequired
    case annotationSelected(Location)
    case deletePolygon(UUID)

    var model: AlertModel {
        switch self {
        case .custom(let model, _, _):
            return model
        case .customThreeButton(let model, _, _, _):
            return model
        case .loggedOut:
            return AlertModel.loggedOutAlert()
        case .authRequired:
            return AlertModel.authRequiredAlert()
        case .annotationSelected(let location):
            return AlertModel(
                title: "선택한 포인트를 삭제할까요?",
                message: "잘못 찍은 포인트라면 지금 지도에서 제거할 수 있어요.\n\(location.coordinate.latitude), \(location.coordinate.longitude)",
                tone: .danger,
                configure: .twoButtonChoice(isVertical: false, first: "취소", second: "삭제"),
                buttonRoles: [.secondary, .destructive]
            )
        case .deletePolygon(_):
            return AlertModel(
                title: "선택한 영역을 삭제할까요?",
                message: "삭제하면 현재 지도에서 즉시 사라지고 되돌릴 수 없어요.",
                tone: .danger,
                configure: .twoButtonChoice(isVertical: false, first: "취소", second: "삭제"),
                buttonRoles: [.secondary, .destructive]
            )
        }
    }
}

enum AlertConfigureType {
    case defaultType
    case twoButtonChoice(isVertical: Bool = false, first: String?, second: String?)
    case threeButtonChoice(first: String?, second: String?, third: String?)
    case oneButton(buttonMsg: String?)

    var leftString: String {
        switch self {
        case .defaultType :
            "확인"
        case .twoButtonChoice(_, first: let first, _):
            first ?? "확인"
        case .threeButtonChoice(let first, _, _):
            first ?? "확인"
        case .oneButton(buttonMsg: let buttonMsg):
            buttonMsg ?? "확인"
        }
    }
    var middleString: String? {
        switch self {
        case .threeButtonChoice(_, let second, _):
            return second ?? "취소"
        default:
            return nil
        }
    }
    var rightString: String? {
        switch self {
        case .defaultType :
            return "취소"
        case .twoButtonChoice(_, _, let second):
            return second ?? "취소"
        case .threeButtonChoice(_, _, let third):
            return third ?? "취소"
        case .oneButton(buttonMsg: _):
            return nil
        }
    }
}

// MARK: Alert Configuration
struct AlertModel {
    private let title: String
    private let message: String?
    private let tone: AlertSurfaceTone
    private let configure: AlertConfigureType
    private let buttonRoles: [AlertActionSemanticRole]
    private let dismissOnBackdropTap: Bool

    init(
        title: String,
        message: String?,
        tone: AlertSurfaceTone = .neutral,
        configure: AlertConfigureType,
        buttonRoles: [AlertActionSemanticRole] = [],
        dismissOnBackdropTap: Bool = true
    ) {
        self.title = title
        self.message = message
        self.tone = tone
        self.configure = configure
        self.buttonRoles = buttonRoles
        self.dismissOnBackdropTap = dismissOnBackdropTap
    }

    static func simpleAlert(title: String, message: String = "", isOneButton: Bool = false) -> AlertModel{
        if isOneButton {
            AlertModel(
                title: title,
                message: message,
                tone: .caution,
                configure: .oneButton(buttonMsg: "확인"),
                buttonRoles: [.primary]
            )
        } else {
            AlertModel(
                title: title,
                message: message,
                tone: .caution,
                configure: .twoButtonChoice(isVertical: true, first: "예", second: "아니오"),
                buttonRoles: [.primary, .secondary]
            )
        }
    }

    static func threeChoiceAlert(
        title: String,
        message: String,
        first: String,
        second: String,
        third: String
    ) -> AlertModel {
        AlertModel(
            title: title,
            message: message,
            tone: .caution,
            configure: .threeButtonChoice(first: first, second: second, third: third),
            buttonRoles: [.primary, .secondary, .destructive]
        )
    }

    /// 로그아웃 완료 안내에 사용하는 단일 버튼 알림 모델을 생성합니다.
    /// - Parameter primaryButtonTitle: 로그인 재진입 버튼에 표시할 문구입니다.
    /// - Returns: 로그아웃 완료 안내 문구와 단일 버튼 구성을 담은 알림 모델입니다.
    static func loggedOutAlert(primaryButtonTitle: String = "로그인 하기") -> AlertModel {
        AlertModel(
            title: "계정 오류",
            message: "로그아웃 되었습니다.",
            tone: .danger,
            configure: .oneButton(buttonMsg: primaryButtonTitle),
            buttonRoles: [.primary],
            dismissOnBackdropTap: false
        )
    }

    /// 인증 세션 확인이 필요한 상태를 안내하는 단일 버튼 알림 모델을 생성합니다.
    /// - Parameter primaryButtonTitle: 로그인 재진입 버튼에 표시할 문구입니다.
    /// - Returns: 인증 재확인 안내 문구와 단일 버튼 구성을 담은 알림 모델입니다.
    static func authRequiredAlert(primaryButtonTitle: String = "로그인 하기") -> AlertModel {
        AlertModel(
            title: "인증 필요",
            message: "인증 세션 확인이 필요합니다. 다시 로그인 후 시도해주세요.",
            tone: .caution,
            configure: .oneButton(buttonMsg: primaryButtonTitle),
            buttonRoles: [.primary],
            dismissOnBackdropTap: false
        )
    }

    func titleStr() -> String {
        return self.title
    }
    func messageStr() -> String {
        return self.message ?? ""
    }
    func leftActionText() -> String {
        return self.configure.leftString
    }
    func middleActionText() -> String? {
        return self.configure.middleString
    }
    func rightActionText() -> String? {
        return self.configure.rightString
    }

    var preferredButtonLayout: AlertButtonLayout {
        switch configure {
        case .defaultType:
            return .vertical
        case .twoButtonChoice(let isVertical, _, _):
            return isVertical ? .vertical : .adaptive
        case .threeButtonChoice:
            return .vertical
        case .oneButton:
            return .vertical
        }
    }

    var surfaceTone: AlertSurfaceTone {
        tone
    }

    var allowsBackdropDismiss: Bool {
        dismissOnBackdropTap
    }

    var buttonDescriptors: [AlertButtonDescriptor] {
        let titles = [leftActionText(), middleActionText(), rightActionText()].compactMap { $0 }
        let normalizedRoles = normalizedButtonRoles(for: titles.count)
        return zip(titles.indices, zip(titles, normalizedRoles)).map { entry in
            let (index, pair) = entry
            let (title, role) = pair
            return AlertButtonDescriptor(
                id: "customAlert.action.\(role.rawValue).\(index)",
                title: title,
                role: role
            )
        }
    }

    func height(isShowVerticalButtons: Bool = false) -> CGFloat {
        let layout = isShowVerticalButtons ? AlertButtonLayout.vertical : preferredButtonLayout
        switch layout {
        case .horizontal:
            return title.isEmpty ? 190 : 214
        case .adaptive, .vertical:
            return title.isEmpty ? 216 : 248
        }
    }

    /// 버튼 개수에 맞는 의미 계층 배열을 반환합니다.
    /// - Parameter count: 현재 알림에 실제로 노출될 버튼 개수입니다.
    /// - Returns: 각 버튼에 대응하는 의미 계층 배열입니다.
    private func normalizedButtonRoles(for count: Int) -> [AlertActionSemanticRole] {
        let fallback: [AlertActionSemanticRole]
        switch count {
        case 0:
            fallback = []
        case 1:
            fallback = [.primary]
        case 2:
            fallback = [.secondary, .primary]
        default:
            fallback = [.primary, .secondary, .destructive]
        }

        guard buttonRoles.count == count else { return fallback }
        return buttonRoles
    }
}
