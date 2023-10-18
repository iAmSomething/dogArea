//
//  CustomAlertViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 10/17/23.
//

import Foundation
import SwiftUI
class CustomAlertViewModel: ObservableObject {
    @State var test: Bool = false
    @Published var customAlert: CustomAlert? = nil
    @ObservedObject var loc: LocationManager = .init()
}
extension CustomAlertViewModel {
    func toggleTest() {
        test.toggle()
    }
    func callAlert(type: AlertActionType, state: Binding<Bool>) -> some View {
        if customAlert == nil {
            setAlert(type: type, state: state)
        }
        return self.customAlert
    }
    private func setAlert(type: AlertActionType, state: Binding<Bool>){
        switch type {
        case .custom(alert: let alert):
            self.customAlert = alert
        case .addPoint:
            self.customAlert = CustomAlert(presentAlert: state
                                           ,alertType: .customValue(title: "오줌",
                                                                    message: "오줌 눴습니까?",
                                                                    configure: .twoButtonChoice(isVertical: false, first: "네", second: "아니오")),
                                           isShowVerticalButtons: false,
                                           leftButtonAction: {
                withAnimation{self.loc.callLocation()}
            }, rightButtonAction: {
                print("아니오")
            })
        case .logOut:
            self.customAlert = CustomAlert(presentAlert:state)
            
        }
    }
    enum AlertActionType{
        case custom(alert: CustomAlert)
        case addPoint
        case logOut
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
