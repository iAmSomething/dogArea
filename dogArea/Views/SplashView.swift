//
//  SplashView.swift
//  dogArea
//
//  Created by 김태훈 on 11/7/23.
//

import SwiftUI
import Lottie
struct SplashView: View {
  @State private var firstText = false
  @State private var secondText = false
  var body: some View {
    ZStack {
      LottieView(jsonName: "dogAreaSplash", loopMode: .loop)
        .background(Color.appYellowPale)
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear{
          DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
              firstText = true
            }
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
              secondText = true
            }
          }
        }
      VStack(alignment: .leading, spacing: 0) {
        if firstText {
          HStack {
            Text("우리집 강아지의")
              .font(.appFont(for: .Thin, size: 40))
              .padding(.leading, 20)
              .frame(maxHeight: .infinity)
              .aspectRatio(contentMode: .fit)
            Spacer()
          }
        }
        if secondText {
          HStack (spacing: 0){
            Text("영역을 표시해요")
              .font(.appFont(for: .Thin, size: 40))
              .padding(.leading, 20)
              .frame(maxHeight: .infinity)
              .aspectRatio(contentMode: .fit)
            Spacer()
          }
        }
        Spacer()
      }
      .padding(.top,80)
      .frame(width: .screenX())
        .frame(minHeight: 100, maxHeight: .infinity)
    }
  }
}

#Preview {
  SplashView()
}

