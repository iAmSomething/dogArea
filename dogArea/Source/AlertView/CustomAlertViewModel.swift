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
public class CustomAlertViewModel: ObservableObject {
  @Published var alertType : AlertActionType
  @Published var isAlert: Bool = false
  init(isAlert: Bool = false, type: AlertActionType = .logOut) {
    self.isAlert = isAlert
    self.alertType = type
  }
}
extension CustomAlertViewModel {
  func callAlert(type: AlertActionType) {
    self.alertType = type
    isAlert.toggle()
  }
}

struct AlertViewModifier: ViewModifier {
  @EnvironmentObject var AlertVM: CustomAlertViewModel
  func body(content: Content) -> some View {
    content
  }
}
protocol AlertCallable {
  var AlertVM: CustomAlertViewModel { get }
}
