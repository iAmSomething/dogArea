//
//  WalkListView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct WalkListView: View {
    @ObservedObject private var viewModel = WalkListViewModel()
    @State private var scrollPosition: CGFloat = 0

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
            }.refreshable {
                viewModel.fetchModel()
            }.onAppear{
                viewModel.fetchModel()
            }
            .navigationDestination(for: WalkDataModel.self) { model in
                WalkListDetailView(viewModel: viewModel, model: model)
            }.navigationTitle("산책 목록")
                .font(.appFont(for: .ExtraBold, size: 36))

        }
        
    }
}

#Preview {
    WalkListView()
}
