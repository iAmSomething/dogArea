//
//  CustomAlertViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 10/17/23.
//

import Foundation
import SwiftUI
import MapKit
import Combine
@MainActor
public final class CustomAlertViewModel: ObservableObject {
  @Published var alertType : AlertActionType
  @Published var isAlert: Bool = false
  init(isAlert: Bool = false, type: AlertActionType = .logOut) {
    self.isAlert = isAlert
    self.alertType = type
  }
}
extension CustomAlertViewModel {
  /// 지정한 알림 타입으로 알림 표시 상태를 활성화합니다.
  /// - Parameter type: 화면에 표시할 알림 타입입니다.
  func callAlert(type: AlertActionType) {
    self.alertType = type
    isAlert = true
  }
    /// 커스텀 알림 모델과 버튼 액션을 설정하고 알림 표시 상태를 활성화합니다.
    /// - Parameters:
    ///   - model: 알림에 표시할 제목/메시지/버튼 구성을 담은 모델입니다.
    ///   - leftAction: 좌측(기본) 버튼 탭 시 실행할 동작입니다.
    ///   - rightAction: 우측 버튼 탭 시 실행할 동작입니다.
    func callCustomAlert(model: AlertModel,leftAction: @escaping () -> (),rightAction: @escaping () -> () = {}) {
        self.alertType = .custom(model, leftAction, rightAction)
        isAlert = true
    }
}
