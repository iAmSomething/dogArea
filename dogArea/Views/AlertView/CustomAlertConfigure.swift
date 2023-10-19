//
//  CustomAlertConfigure.swift
//  dogArea
//
//  Created by 김태훈 on 10/17/23.
//

import Foundation
enum AlertActionType{
  case custom(AlertModel)
  case addPoint
  case logOut
  case annotationSelected(Location)
  var model: AlertModel {
    switch self {
    case .custom(let model):
      return model
    case .addPoint:
      return AlertModel(title: "영역 표시", message: "영역을 표시하겠습니까?", configure: .defaultType)
    case .logOut:
      return AlertModel(title: "계정 오류", message: "로그아웃 되었습니다.", configure: .oneButton(buttonMsg: "로그인 하기"))
    case .annotationSelected(let location):
      return AlertModel(title: "선택된 포인트", message: "\(location.coordinate)", configure: .twoButtonChoice(isVertical: false, first: "확인", second: "삭제"))
    }
  }
}
enum AlertConfigureType {
  case defaultType
  case twoButtonChoice(isVertical: Bool = false, first: String?, second: String?)
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
struct AlertModel {
  private let title: String
  private let message: String?
  private let configure: AlertConfigureType
  init(title: String, message: String?, configure: AlertConfigureType) {
    self.title = title
    self.message = message
    self.configure = configure
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
  func rightActionText() -> String? {
    return self.configure.rightString
  }
  func height(isShowVerticalButtons: Bool = false) -> CGFloat {
    
    return isShowVerticalButtons ? 220 : 150
    
    
  }
  func height(_ setHeight: CGFloat) -> CGFloat {
    return setHeight
  }
}

