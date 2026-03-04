//
//  SplashView.swift
//  dogArea
//
//  Created by 김태훈 on 11/7/23.
//

import SwiftUI
struct SplashView: View {
  @State private var firstText = false
  @State private var secondText = false
  @State private var pulse = false
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color.appYellowPale, Color.appSurface.opacity(0.95)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
        .overlay(
          Circle()
            .fill(Color.appYellow.opacity(0.2))
            .frame(width: 220, height: 220)
            .scaleEffect(pulse ? 1.05 : 0.92)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
            .offset(x: 90, y: 160)
        )
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear{
          pulse = true
          DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {firstText = true}
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {secondText = true}
          }
        }
      VStack(alignment: .leading, spacing: 0) {
        if firstText {
          HStack {
            Text("우리집 강아지의")
                  .foregroundStyle(Color.black)
              .font(.appFont(for: .Thin, size: 40))
              .padding(.leading, 20)
              .frame(maxHeight: .infinity)
              .aspectRatio(contentMode: .fit)
            Spacer()
          }.padding(.bottom, -25)
        }
        if secondText {
          HStack (spacing: 0){
            Text("영역을 표시해요")
                  .foregroundStyle(Color.black)
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
