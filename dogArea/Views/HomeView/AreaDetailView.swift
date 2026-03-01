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
                                    Image(systemName: "pawprint.circle.fill")
                                        .font(.system(size: 68, weight: .semibold))
                                        .foregroundStyle(Color.appYellow)
                                        .padding(.top, 10)
                                    Text(item.createdAt.createdAtTimeDescriptionSimple)
                                        .font(.appFont(for: .Light, size: 15))
                                        .foregroundStyle(Color.appTextDarkGray)
                                }.padding(.horizontal, 20)
                            }.frame(maxWidth: .infinity)
                                .appCardSurface()
                        }
                    }
                }, header: {AreaDetailListHeaderView(viewModel: viewModel)})

                if viewModel.areaReferenceSections.isEmpty == false {
                    Section(content: {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.areaReferenceSections, id: \.id) { section in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(section.catalogName)
                                            .font(.appFont(for: .SemiBold, size: 16))
                                        Spacer()
                                        Text("총 \(section.references.count)개")
                                            .font(.appFont(for: .Light, size: 12))
                                            .foregroundStyle(Color.appTextDarkGray)
                                    }
                                    ForEach(Array(section.references.prefix(5)), id: \.id) { reference in
                                        HStack {
                                            Text(reference.referenceName)
                                                .font(.appFont(for: .Regular, size: 13))
                                                .lineLimit(1)
                                            Spacer()
                                            if reference.isFeatured {
                                                Text("featured")
                                                    .font(.appFont(for: .SemiBold, size: 10))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(Color.appYellowPale)
                                                    .cornerRadius(6)
                                            }
                                            Text(reference.areaM2.calculatedAreaString)
                                                .font(.appFont(for: .Light, size: 12))
                                                .foregroundStyle(Color.appTextDarkGray)
                                        }
                                    }
                                }
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.appTextDarkGray, lineWidth: 0.2)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }, header: {
                        HStack {
                            Text("비교군 카탈로그 (\(viewModel.areaReferenceSourceLabel))")
                                .font(.appFont(for: .SemiBold, size: 20))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            Spacer()
                        }
                        .background(schemeBackgroundColor())
                    })
                }
            }
        }.onAppear{
            tabStatus.hide()
            viewModel.refreshAreaList()
            viewModel.refreshAreaReferenceCatalogs()
        }.onDisappear {
            tabStatus.appear()
        }.refreshable {
            viewModel.refreshAreaList()
            viewModel.refreshAreaReferenceCatalogs()
        }
    }

    private func schemeBackgroundColor() -> Color {
        Color.white
    }
}