//
//  RankingView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct RankingView: View {
  @ObservedObject private var viewModel = RankingViewModel()
  var body: some View {
    NavigationStack {
      List {
        ForEach(viewModel.walkingDatas, id:\.self) { walk in
          NavigationLink(value: walk) {
            RankingListCell(walkData: walk)
              .padding()
              .cornerRadius(15)
              .overlay(
                RoundedRectangle(cornerRadius: 15)
                  .stroke(Color.appTextDarkGray, lineWidth: 0.3)
              )
          }
        }
      }.navigationDestination(for: WalkDataModel.self) { _ in
        ProfileSettingsView()
          .frame(width: .infinity, height: .infinity)
          .ignoresSafeArea()
      }.navigationTitle("산책 목록")
        .font(.appFont(for: .ExtraBold, size: 36))
    }
   
  }
}

#Preview {
  RankingView()
}
