//
//  WalkListView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct WalkListView: View {
  @ObservedObject private var viewModel = WalkListViewModel()
  var body: some View {
    NavigationStack {
      List {
        ForEach(viewModel.walkingDatas, id:\.self) { walk in
          NavigationLink(value: walk) {
            WalkListCell(walkData: walk)
          }.padding()
          .cornerRadius(15)
            .overlay(
              RoundedRectangle(cornerRadius: 15)
                .stroke(Color.appTextDarkGray, lineWidth: 0.3)
            )
        }
      }.navigationDestination(for: WalkDataModel.self) { _ in
        ProfileSettingsView()
          .ignoresSafeArea()
      }.navigationTitle("산책 목록")
        .font(.appFont(for: .ExtraBold, size: 36))
    }
   
  }
}

#Preview {
  WalkListView()
}
