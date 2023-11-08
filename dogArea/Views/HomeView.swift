//
//  HomeView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct HomeView: View {
  @State private var showModal = false
  @State private var settingsDetent = PresentationDetent.medium
  init() {
    print("홈뷰 이닛")
  }
    var body: some View {
        Button("Show Modal") {
            withAnimation {
                self.showModal = true
            }
        }
        .sheet(isPresented: $showModal) {
          ProfileSettingsView()
            .presentationDetents([.medium],
                                 selection: $settingsDetent)
        }
    }
}

#Preview {
    HomeView()
}
