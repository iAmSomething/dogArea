//
//  HomeView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack{
                HStack {
                    Text("강아지의 영역")
                        .font(.appFont(for: .SemiBold, size: 40))
                        .padding()
                    Spacer()
                }
                Picker("도시들",selection: $viewModel.myArea) {
                    ForEach(viewModel.combinedAreas(), id: \.self) { item in
                        HStack {
                            Text(item.areaName)
                                .font(.appFont(for: .Medium, size: 20))
                            Text(item.area.calculatedAreaString).font(.appFont(for: .Medium, size: 20))
                        }
                    }
                }.pickerStyle(.inline)
                    .frame(height: 120)
                    .background(Color.appPeach)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 10)
                    .shadow(radius: 5)
                    .disabled(true)
                UnderLine()
                VStack {
                    HStack {
                        Text("다음 목표는")
                            .font(.medium16)
                            .padding([.leading, .bottom], 20)
                        Spacer()
                    }
                    HStack(alignment: .bottom) {
                        if let area = viewModel.nearlistMore() {
                            Text("\(area.areaName)")
                                .font(.appFont(for: .Bold, size: 40))
                            Text("입니다.")
                        } else {
                            Text("더 정복할 곳이 없어요!")
                                .font(.appFont(for: .Medium, size: 20))
                                .onTapGesture {
                                }
                        }
                    }.padding()
                        .background(Color.appPinkYello)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding(.bottom)

                }
                UnderLine()
                VStack {
                    HStack {
                        Text("가장 최근에 정복한 곳은")
                            .font(.medium16)
                            .padding([.leading, .bottom], 20)
                        Spacer()
                    }
                    HStack(alignment: .bottom) {
                        if let area = viewModel.nearlistLess() {
                            Text("\(area.areaName)")
                                .font(.appFont(for: .Bold, size: 40))
                            Text("입니다.")
                        } else {
                            Text("산책을 통해 영역을 넓혀봐요!")
                                .font(.appFont(for: .Medium, size: 20))
                                .onTapGesture {
                                }
                        }
                    }.padding()
                        .background(Color.appPinkYello)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding(.bottom)

                }
                UnderLine()

                Spacer()
                #if DEBUG
                Button("영역 올리기") {
                    viewModel.makeitup()
                }
                Button("초기화") {
                    viewModel.reset()
                }
                #endif
            }
        }
    }
}

#Preview {
    HomeView()
}

