//
//  StartButtonView.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import Foundation
import SwiftUI
struct StartButtonView: View {
  @ObservedObject var viewModel: MapViewModel
  var body: some View {
    HStack {
      if viewModel.isWalking {
        Spacer()
        Text("영역 넓이\n" + String(format: "%.2f" , viewModel.calculateArea()) + "㎡")
          .frame(width: 100)
          .multilineTextAlignment(.center)
          .font(.appFont(for: .Light, size: 18))
        
        Spacer()
      }
      Image(viewModel.isWalking ? .stopIcon : .startIcon)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 64, height: 64)
      
        .onTapGesture {
          viewModel.endWalk()
        }
      if viewModel.isWalking {
        Spacer()
        Text("산책시작\n" + viewModel.time.simpleWalkingTimeInterval)
          .multilineTextAlignment(.center)
          .frame(width: 100)
          .font(.appFont(for: .Light, size: 18))
        Spacer()
      }
    }.frame(width: screenSize.width, height: screenSize.height * 0.1)
      .background(viewModel.isWalking ? Color.white : Color.clear)
      .animation(.easeIn, value: viewModel.isWalking)
  }
}
