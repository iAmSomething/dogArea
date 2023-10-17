//
//  CustomAlertView.swift
//  dogArea
//
//  Created by 김태훈 on 10/16/23.
//

import Foundation
import SwiftUI
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
        case .twoButtonChoice(_, first: let first, _):
            first ?? "취소"
        case .oneButton(buttonMsg: _):
            nil
        }
    }
}
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
/// A boolean State variable is required in order to present the view.
struct CustomAlert: View {
    
    /// Flag used to dismiss the alert on the presenting view
    @Binding var presentAlert: Bool
    
    /// The alert type being shown
    @State var alertType: AlertType = .defaultValue(configure: .defaultType)
    
    /// based on this value alert buttons will show vertically
    var isShowVerticalButtons = false
    
    var leftButtonAction: (() -> ())?
    var rightButtonAction: (() -> ())?
    
    var verticalButtonsHeight: CGFloat = 80
    
    var body: some View {
        
        ZStack {
            
            // faded background
            Color.black.opacity(0.75)
                .edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                Spacer()
                if alertType.title() != "" {
                    // alert title
                    Text(alertType.title())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .frame(height: 25)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        .padding(.horizontal, 16)
                }
//                Divider()
//                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 0.5)
//                    .padding(.all, 0)
                // alert message
                Text(alertType.message())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .aspectRatio(contentMode: .fit)
                //                        .minimumScaleFactor(0.5)
                Divider()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 0.5)
                    .padding(.all, 0)
                if !isShowVerticalButtons {
                    HStack(spacing: 0) {
                        // left button
                        if (!alertType.leftActionText.isEmpty) {
                            Button {
                                withAnimation{
                                    leftButtonAction?()
                                    presentAlert.toggle()
                                }
                            } label: {
                                Text(alertType.leftActionText)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                            }
                            Divider()
                                .frame(minWidth: 0, maxWidth: 0.5, minHeight: 0, maxHeight: .infinity)
                        }
                        if let rightTxt = alertType.rightActionText {
                            // right button (default)
                            Button {
                                withAnimation{
                                    rightButtonAction?()
                                    presentAlert.toggle()
                                }
                                
                            } label: {
                                Text(rightTxt)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.pink)
                                    .multilineTextAlignment(.center)
                                    .padding(15)
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                            }
                        }
                        
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 55)
                    .padding([.horizontal, .bottom], 0)
                    
                } else {
                    VStack(spacing: 0) {
                        Spacer()
                        Button {
                            withAnimation{
                                leftButtonAction?()
                                presentAlert.toggle()
                            }
                            
                        } label: {
                            Text(alertType.leftActionText)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        }
                        
                        Spacer()
                        if let rightTxt = alertType.rightActionText {
                            Divider()
                            
                            Spacer()
                            Button {
                                withAnimation(.bouncy){
                                    rightButtonAction?()
                                    presentAlert.toggle()
                                }
                            } label: {
                                Text(rightTxt)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.pink)
                                    .multilineTextAlignment(.center)
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                            }
                            Spacer()
                        }
                    }
                    .frame(height: verticalButtonsHeight)
                }
                Spacer()
            }
            .frame(minWidth: 270, maxWidth: .infinity, minHeight: alertType.height(isShowVerticalButtons: isShowVerticalButtons), maxHeight: .infinity)
            //                .frame(width: 270, height: alertType.height(isShowVerticalButtons: isShowVerticalButtons))
            .background(.white)
            .cornerRadius(4)
            .padding(.horizontal, 50)
            .aspectRatio(contentMode: .fit)
        }
        .zIndex(2)
    }
    
}
