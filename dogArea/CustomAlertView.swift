//
//  CustomAlertView.swift
//  dogArea
//
//  Created by 김태훈 on 10/16/23.
//

import Foundation
import SwiftUI

struct CustomAlertView: View {
    @Binding var showAlert: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .foregroundStyle(.white)
                .overlay(RoundedRectangle(cornerRadius: 30)
                    .stroke(.gray.opacity(0.2), lineWidth: 1))
                .shadow(color: .gray.opacity(0.4), radius: 4)
            
            VStack {
                Spacer()
                CustomAlertView(showAlert: $showAlert)
            }.padding(.vertical)
        }.padding(50)
    }
}
extension CustomAlertView {
    struct AlertButton: View {
        @Binding var showAlert: Bool
//        var act: () -> Void
//        init(isOpen: Binding<Bool> , act: @escaping () -> Void) {
//            self._showAlert = isOpen
//            self.act = act
//        }
        var body: some View {
            Button(action: {
//                act()
                print("closed")
                self.showAlert = false
            }, label: {Text("Close")
                    .foregroundStyle(.white)
                    .font(.headline)
                    .padding()
                    .background(.cyan)
                    .cornerRadius(26)
                    .padding(10)
            })
        }
    }
}

final class customAlert {
    @Published var isOpen: Bool = true
    func addAlert(okAction: @escaping () -> Void, cancelAction: @escaping () -> Void) {
        self.isOpen = true
        
    }
    @ViewBuilder
    public func addAlert<A>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View where A : View {
        
    }
}
