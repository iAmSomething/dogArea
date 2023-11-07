//
//  SplashView.swift
//  dogArea
//
//  Created by 김태훈 on 11/7/23.
//

import SwiftUI
import Lottie
struct SplashView: View {
  var body: some View {
    LottieView(jsonName: "dogAreaSplash", loopMode: .loop)
      .background(Color.yellow)
      .ignoresSafeArea()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview {
  SplashView()
}

