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
    @ObservedObject var myAlert: CustomAlertViewModel
    @Binding var isModalPresented: Bool
    @Binding var endWalkingViewPresented: Bool
    @State var isMeter: Bool = true
    var body: some View {
        HStack {
            if viewModel.isWalking {
                Spacer()
                Text("영역 넓이\n" + viewModel.calculatedAreaString(isPyong: !isMeter))
                    .frame(width: 100)
                    .multilineTextAlignment(.center)
                    .font(.appFont(for: .Light, size: 18))
                    .onTapGesture {isMeter.toggle()}
                Spacer()
            }
            Image(viewModel.isWalking ? .stopIcon : .startIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .onTapGesture {
                    if !viewModel.isWalking {
                        isModalPresented.toggle()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            isModalPresented = false
                            viewModel.endWalk()
                        }
                    }
                    else {
                        myAlert.callAlert(
                            type: .custom(.simpleAlert(title: "산책 종료", message: "정말 산책을 마치겠습니까?") ,
                                          {
                                              viewModel.timerStop()
                                              if viewModel.polygon.locations.count > 2 {
                                                  viewModel.makePolygon()
                                                  endWalkingViewPresented.toggle()
                                              } else {
                                                  viewModel.endWalk()
                                              }
                                          },
                                          {})
                        )
                    }
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
