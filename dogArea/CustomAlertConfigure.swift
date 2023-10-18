//
//  CustomAlertConfigure.swift
//  dogArea
//
//  Created by 김태훈 on 10/17/23.
//

import Foundation
enum AlertConfigureType {
    case defaultType
    case twoButtonChoice(isVertical: Bool, first: String?, second: String?)
    case oneButton(buttonMsg: String?)
    var leftString: String {
        switch self {
        case .defaultType :
            "확인"
        case .twoButtonChoice(_, first: let first, _):
            first ?? "확인"
        case .oneButton(buttonMsg: let buttonMsg):
            buttonMsg ?? "확인"
        }
    }
    var rightString: String? {
        switch self {
        case .defaultType :
            "취소"
        case .twoButtonChoice(_, _, let second):
            second ?? "취소"
        case .oneButton(buttonMsg: _):
            nil
        }
    }
}
// MARK: 알림 기능
// TODO: 로그인 추가 시 권한 없음 case 추가, customView 추가 기능
enum AlertType {
    case defaultValue(configure: AlertConfigureType = .defaultType)
    case customValue(title: String, message: String = "",configure: AlertConfigureType = .defaultType)
    
    func title() -> String {
        switch self {
        case .defaultValue :
            return "제목 영역입니다."
        case .customValue(title: let title, _, _) :
            return title
        }
    }
    func message() -> String {
        switch self {
        case .defaultValue :
            return "확인 하시겠습니까?"
        case .customValue(_, message: let msg, _) :
            return msg
        }
    }
    var leftActionText: String {
        switch self {
        case .defaultValue(configure: let conf):
            conf.leftString
        case .customValue(_,_,configure: let conf):
            conf.leftString
        }
    }
    var rightActionText: String? {
        switch self {
        case .defaultValue(configure: let conf):
            return conf.rightString
        case .customValue(_,_,configure: let conf):
            return conf.rightString
        }
    }
    func height(isShowVerticalButtons: Bool = false) -> CGFloat {
        switch self {
        case .defaultValue:
            return isShowVerticalButtons ? 220 : 150
        case .customValue(_, _, _):
            return isShowVerticalButtons ? 220 : 150
        }
    }
    func height(_ setHeight: CGFloat) -> CGFloat {
        return setHeight
    }
}
