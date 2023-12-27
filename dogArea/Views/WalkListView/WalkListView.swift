//
//  WalkListView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct WalkListView: View {
    @StateObject var tabStatus = TabAppear.shared
    @ObservedObject private var viewModel = WalkListViewModel()
    @State private var scrollPosition: CGFloat = 0
    @Environment(\.colorScheme) var scheme
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(pinnedViews: [.sectionHeaders]) {
                    Section(content: {
                        VStack {
                            ForEach(viewModel.walkingDatas.thisWeekList.reversed(), id:\.self) { walk in
                                NavigationLink(value: walk) {
                                    WalkListCell(walkData: walk)
                                }.padding()
                                    .cornerRadius(15)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.appTextDarkGray, lineWidth: 0.3)
                                    )
                                    .padding(.horizontal, 15)
                            }
                        }
                    }, header: {HStack {
                        Text("이번 주 산책 목록")
                            .font(.appFont(for: .SemiBold, size: 20))
                            .padding()
                        Spacer()
                    }.background(scheme == .dark ? Color.black : Color.white)
                    })
                    Section(content: {
                        VStack {
                            ForEach(viewModel.walkingDatas.exceptThisWeek.reversed(), id:\.self) { walk in
                                NavigationLink(value: walk) {
                                    WalkListCell(walkData: walk)
                                        
                                }.padding()
                                    .cornerRadius(15)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                        /Users/gimtaehun/멋사/dogArea/dogArea/Views/WalkListView/WalkListSubView                   .stroke(Color.appTextDarkGray, lineWidth: 0.3)
                                    )
                                    .padding(.horizontal, 15)

                            }
                        }

                    }, header: {HStack {
                        Text("이전 산책 목록")
                            .font(.appFont(for: .SemiBold, size: 20))
                            .padding()
                        Spacer()
                    }.background(scheme == .dark ? Color.black : Color.white)
                    })
                    
                }
            }.refreshable {
                viewModel.fetchModel()
            }.onAppear{
                tabStatus.appear()

                viewModel.fetchModel()
            }.navigationDestination(for: WalkDataModel.self) { model in
                WalkListDetailView(model: model)
            }.navigationTitle("산책 목록")
                .font(.appFont(for: .ExtraBold, size: 36))
        }
    }
}

#Preview {
    WalkListView()
}
