//
//  CustomAlertView.swift
//  dogArea
//
//  Created by 김태훈 on 10/16/23.
//

import Foundation
import SwiftUI

struct CustomAlert: View {
  @Binding var presentAlert: Bool
  /// The alert type being shown
  @State var alertModel: AlertModel
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
        .onTapGesture {
          self.presentAlert.toggle()
        }
      VStack(spacing: 0) {
        Spacer()
        if alertModel.titleStr() != "" {
          // alert title
          title
        }
        msg
        //                        .minimumScaleFactor(0.5)
        Divider()
          .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 0.5)
          .padding(.all, 0)
        if !isShowVerticalButtons {
          verticalBtn
        } else {
          horizontalBtn
        }
        Spacer()
      }
      .frame(minWidth: 270, maxWidth: .infinity, minHeight: alertModel.height(isShowVerticalButtons: isShowVerticalButtons), maxHeight: .infinity)
      //                .frame(width: 270, height: alertType.height(isShowVerticalButtons: isShowVerticalButtons))
      .background(.white)
      .cornerRadius(4)
      .padding(.horizontal, 50)
      .aspectRatio(contentMode: .fit)
    }
    .zIndex(2)
  }
  
}
// MARK: Alert 뷰 구성
extension CustomAlert {
  var title: some View {
    Text(alertModel.titleStr())
      .font(.system(size: 16, weight: .bold))
      .foregroundColor(.black)
      .multilineTextAlignment(.center)
      .frame(height: 25)
      .padding(.top, 16)
      .padding(.bottom, 8)
      .padding(.horizontal, 16)
  }
  var msg: some View {
    Text(alertModel.messageStr())
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .font(.system(size: 14))
      .foregroundColor(.black)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 16)
      .padding(.bottom, 16)
      .aspectRatio(contentMode: .fit)
  }
  var verticalBtn: some View {
    HStack(spacing: 0) {
      // left button
      if (!alertModel.leftActionText().isEmpty) {
        Button {
          withAnimation{
            leftButtonAction?()
            presentAlert.toggle()
          }
        } label: {
          Text(alertModel.leftActionText())
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .padding()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
        Divider()
          .frame(minWidth: 0, maxWidth: 0.5, minHeight: 0, maxHeight: .infinity)
      }
      if let rightTxt = alertModel.rightActionText() {
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
  }
  var horizontalBtn: some View {
    VStack(spacing: 0) {
      Spacer()
      Button {
        withAnimation{
          leftButtonAction?()
          presentAlert.toggle()
        }
        
      } label: {
        Text(alertModel.leftActionText())
          .font(.system(size: 16, weight: .bold))
          .foregroundColor(.black)
          .multilineTextAlignment(.center)
          .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
      }
      
      Spacer()
      if let rightTxt = alertModel.rightActionText() {
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
}
