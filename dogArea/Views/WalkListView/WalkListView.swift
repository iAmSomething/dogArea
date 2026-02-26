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
    @EnvironmentObject var authFlow: AuthFlowCoordinator
    @Environment(\.colorScheme) var scheme
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(pinnedViews: [.sectionHeaders]) {
                    if authFlow.isGuestMode {
                        guestUpgradeCard
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                    }
                    if viewModel.pets.isEmpty == false {
                        petContextSwitcher
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
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
                                            .stroke(Color.appTextDarkGray, lineWidth: 0.3)
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

    var guestUpgradeCard: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("게스트 모드")
                    .font(.appFont(for: .SemiBold, size: 13))
                Text("로그인하면 산책 기록을 백업하고 다른 기기와 동기화할 수 있어요.")
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
            }
            Spacer()
            Button("로그인") {
                _ = authFlow.requestAccess(feature: .cloudSync)
            }
            .font(.appFont(for: .SemiBold, size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.appYellow)
            .cornerRadius(8)
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appTextDarkGray, lineWidth: 0.25)
        )
    }

    var petContextSwitcher: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("현재 반려견 컨텍스트: \(viewModel.selectedPetName)")
                .font(.appFont(for: .SemiBold, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.pets, id: \.petId) { pet in
                        Text(pet.petName)
                            .font(.appFont(for: .Regular, size: 12))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.selectedPetId == pet.petId ? Color.appYellow : Color.appYellowPale
                            )
                            .cornerRadius(8)
                            .onTapGesture {
                                viewModel.selectPet(pet.petId)
                            }
                    }
                }
            }
        }
    }
}

#Preview {
    WalkListView()
}
