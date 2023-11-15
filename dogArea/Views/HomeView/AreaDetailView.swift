//
//  AreaDetailView.swift
//  dogArea
//
//  Created by 김태훈 on 11/14/23.
//

import Foundation
import SwiftUI
struct AreaDetailView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var tabStatus = TabAppear.shared
    
    @ObservedObject var viewModel: HomeViewModel
    var body: some View {
        ScrollView {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("강아지가 정복한 영역들!")
                        .font(.appFont(for: .SemiBold, size: 35))
                    Text("내용 추가 바람")
                        .font(.appFont(for: .Light, size: 15))
                        .foregroundStyle(Color.appTextDarkGray)
                }.padding()
                Spacer()
            }
            
            LazyVStack(pinnedViews: [.sectionHeaders]) {
                Section(content: {
                    VStack {
                        ForEach(viewModel.myAreaList.reversed(), id: \.self) { item in
                            HStack {
                                VStack(alignment:.leading) {
                                    Text("넓이 : " + item.area.calculatedAreaString)
                                        .font(.appFont(for: .Light, size: 13))
                                        .foregroundStyle(Color.appTextDarkGray)
                                    Text(item.areaName)
                                        .font(.appFont(for: .SemiBold, size: 30))
                                }.padding(.leading, 20)
                                Spacer()
                                VStack {
                                    Image(.pawSelected)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                        .padding(.top, 10)
                                    Text(item.createdAt.createdAtTimeDescriptionSimple)
                                        .font(.appFont(for: .Light, size: 15))
                                        .foregroundStyle(Color.appTextDarkGray)
                                }.padding(.horizontal, 20)
                            }.frame(maxWidth: .infinity)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.appTextDarkGray, lineWidth: 0.3)
                                )
                        }
                    }
                }, header: {ListHeaderView(viewModel: viewModel)})
            }
        }.onAppear{
            tabStatus.hide()
            viewModel.refreshAreaList()
        }.onDisappear {
            tabStatus.appear()
        }.refreshable {
            viewModel.refreshAreaList()
        }
    }
}
struct ListHeaderView: View {
    @ObservedObject var viewModel: HomeViewModel
    var body: some View {
        if let next = viewModel.nearlistMore() {
            VStack {
                HStack {
                    Text("다음 목표!")
                        .font(.appFont(for: .SemiBold, size: 25))
                        .padding(.horizontal, 20)
                    Spacer()
                }
                HStack {
                    VStack(alignment:.leading) {
                        Text("넓이 : " + next.area.calculatedAreaString)
                            .font(.appFont(for: .Light, size: 13))
                            .foregroundStyle(Color.appTextDarkGray)
                        HStack(alignment:.bottom) {
                            Text(next.areaName)
                                .font(.appFont(for: .SemiBold, size: 30))
                            Text("까지").font(.appFont(for: .Light, size: 15))
                        }
                        Text((next.area - viewModel.myArea.area).calculatedAreaString + "남았습니다!")
                    }.padding(.leading, 20)
                    Spacer()
                    Image(.paw)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .padding(10)
                }.frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.appTextDarkGray, lineWidth: 0.3)
                    )
                    .padding()
                
            }.background(Color.white)
        }
        
    }
}
