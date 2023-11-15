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
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("산책 달력")
                            .font(.appFont(for: .SemiBold, size: 40))
                        Text("산책한 날을 표시해보아요!")
                            .font(.appFont(for: .Light, size: 15))
                            .foregroundStyle(Color.appTextDarkGray)
                    }.padding()
                    Spacer()
                }
                CalenderView(clickedDates: viewModel.walkedDates())
                UnderLine()
                HStack {
                    VStack{
                        HStack {
                            Text("이번 주 산책한 영역")
                                .font(.appFont(for: .SemiBold, size: 20))
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                        Text("\(viewModel.walkedAreaforWeek().calculatedAreaString)")
                            .font(.appFont(for: .Light, size: 15))
                    }.frame(maxWidth: .infinity)
                        .padding(.leading)
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 0.6)
                        .frame(maxHeight: .infinity)
                        .background(Color(red: 0.19, green: 0.19, blue: 0.19))
                    VStack {
                        HStack {
                            Text("이번 주 산책 횟수")
                                .font(.appFont(for: .SemiBold, size: 20))
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                        Text("\(viewModel.walkedCountforWeek()) 회")
                            .font(.appFont(for: .Light, size: 15))

                    }.frame(maxWidth: .infinity)
                        .padding(.trailing)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("강아지의 영역")
                            .font(.appFont(for: .SemiBold, size: 40))
                        Text("강아지가 정복한 영역을 확인해보세요!")
                            .font(.appFont(for: .Light, size: 15))
                            .foregroundStyle(Color.appTextDarkGray)
                    }.padding()
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
                        if let area = viewModel.nearlistMore() {
                            Text("\((area.area - viewModel.myArea.area).calculatedAreaString) 남았습니다.")
                                .font(.appFont(for: .Light, size: 15))
                                .padding(.trailing, 20)
                                
                        }
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
                    HStack(alignment:.top) {
                        Text("가장 최근에 정복한 곳은")
                            .font(.medium16)
                            .padding([.leading, .bottom], 20)
                        Spacer()
                        NavigationLink(destination: {AreaDetailView(viewModel: viewModel)}, label: {                        Text("더 보기 >")
                                .font(.appFont(for: .Light, size: 14))
                                .foregroundStyle(Color.appTextDarkGray)
                                .padding([.trailing, .bottom], 20)
                                })

                        
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
        }.refreshable {
            viewModel.fetchData()
        }.onAppear{
            viewModel.fetchData()
        }.padding(.top,20)
    }
}

#Preview {
    HomeView()
}

