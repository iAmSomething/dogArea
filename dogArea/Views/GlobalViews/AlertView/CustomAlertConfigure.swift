//
//  CustomAlertConfigure.swift
//  dogArea
//
//  Created by 김태훈 on 10/17/23.
//

import Foundation

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
            return AlertModel(title: "선택된 포인트", message: "\(location.coordinate)", configure: .twoButtonChoice(isVertical: false, first: "확인", second: "삭제"))
        case .deletePolygon(_):
            return AlertModel(title: "영역 선택", message: "선택한 영역을 삭제하시겠습니까?", configure: .twoButtonChoice(isVertical: false, first: "삭제", second: "취소"))
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
    private let configure: AlertConfigureType

    init(title: String, message: String?, configure: AlertConfigureType) {
        self.title = title
        self.message = message
        self.configure = configure
    }

    static func simpleAlert(title: String, message: String = "", isOneButton: Bool = false) -> AlertModel{
        if isOneButton {
            AlertModel(title: title, message: message, configure: .oneButton(buttonMsg: "확인"))
        } else {
            AlertModel(title: title, message: message, configure: .twoButtonChoice(isVertical: true, first: "예", second: "아니오"))
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
            configure: .threeButtonChoice(first: first, second: second, third: third)
        )
    }

    /// 로그아웃 완료 안내에 사용하는 단일 버튼 알림 모델을 생성합니다.
    /// - Parameter primaryButtonTitle: 로그인 재진입 버튼에 표시할 문구입니다.
    /// - Returns: 로그아웃 완료 안내 문구와 단일 버튼 구성을 담은 알림 모델입니다.
    static func loggedOutAlert(primaryButtonTitle: String = "로그인 하기") -> AlertModel {
        AlertModel(
            title: "계정 오류",
            message: "로그아웃 되었습니다.",
            configure: .oneButton(buttonMsg: primaryButtonTitle)
        )
    }

    /// 인증 세션 확인이 필요한 상태를 안내하는 단일 버튼 알림 모델을 생성합니다.
    /// - Parameter primaryButtonTitle: 로그인 재진입 버튼에 표시할 문구입니다.
    /// - Returns: 인증 재확인 안내 문구와 단일 버튼 구성을 담은 알림 모델입니다.
    static func authRequiredAlert(primaryButtonTitle: String = "로그인 하기") -> AlertModel {
        AlertModel(
            title: "인증 필요",
            message: "인증 세션 확인이 필요합니다. 다시 로그인 후 시도해주세요.",
            configure: .oneButton(buttonMsg: primaryButtonTitle)
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
    func height(isShowVerticalButtons: Bool = false) -> CGFloat {
        
        return isShowVerticalButtons ? 220 : 150
        
        
    }
}
