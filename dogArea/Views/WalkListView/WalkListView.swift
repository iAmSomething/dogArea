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
                    if viewModel.walkingDatas.isEmpty {
                        if viewModel.shouldShowSelectedPetEmptyState {
                            filteredEmptyStateCard
                        } else {
                            emptyHistoryCard
                        }
                    } else {
                        if viewModel.walkingDatas.thisWeekList.isEmpty == false {
                            Section(content: {
                                VStack {
                                    ForEach(viewModel.walkingDatas.thisWeekList.reversed(), id:\.self) { walk in
                                        NavigationLink(value: walk) {
                                            WalkListCell(walkData: walk)
                                        }.padding()
                                            .accessibilityIdentifier("walklist.cell")
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
                        }
                        if viewModel.walkingDatas.exceptThisWeek.isEmpty == false {
                            Section(content: {
                                VStack {
                                    ForEach(viewModel.walkingDatas.exceptThisWeek.reversed(), id:\.self) { walk in
                                        NavigationLink(value: walk) {
                                            WalkListCell(walkData: walk)
                                        }.padding()
                                            .accessibilityIdentifier("walklist.cell")
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
                    }
                    
                }
                .padding(.top, 8)
                .padding(.bottom, CustomTabBar.reservedContentHeight + 12)
            }.refreshable {
                viewModel.fetchModel()
            }
            .background(Color.appTabScaffoldBackground)
            .onAppear{
                tabStatus.appear()

                viewModel.fetchModel()
            }.navigationDestination(for: WalkDataModel.self) { model in
                WalkListDetailView(model: model)
            }.navigationTitle("산책 목록")
                .font(.appFont(for: .ExtraBold, size: 36))
                .accessibilityIdentifier("screen.walkList.content")
        }
        .background(Color.appTabScaffoldBackground.ignoresSafeArea())
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
            .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
        }
        .padding(10)
        .appCardSurface()
    }

    var petContextSwitcher: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(viewModel.isShowingAllRecordsOverride
                     ? "전체 기록 보기 모드 · 선택 반려견 \(viewModel.selectedPetName)"
                     : "선택 반려견 기준 · \(viewModel.selectedPetName)")
                .appPill(isActive: viewModel.isShowingAllRecordsOverride == false)
                .accessibilityLabel(
                    viewModel.isShowingAllRecordsOverride
                        ? "전체 기록 보기 모드, 선택 반려견 \(viewModel.selectedPetName)"
                        : "선택 반려견 기준, \(viewModel.selectedPetName)"
                )
                if viewModel.isShowingAllRecordsOverride {
                    Button("기준으로 돌아가기") {
                        viewModel.showSelectedPetRecords()
                    }
                    .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                    .accessibilityLabel("선택 반려견 기준으로 돌아가기")
                }
                Spacer(minLength: 0)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.pets, id: \.petId) { pet in
                        Text(pet.petName)
                            .appPill(isActive: viewModel.selectedPetId == pet.petId)
                            .onTapGesture {
                                viewModel.selectPet(pet.petId)
                            }
                    }
                }
            }
        }
    }

    var filteredEmptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(viewModel.selectedPetName) 산책 기록이 아직 없어요")
                .font(.appFont(for: .SemiBold, size: 14))
            Text("필터 기준으로는 0건입니다. 전체 기록으로 전환하면 다른 반려견 기록을 확인할 수 있어요.")
                .font(.appFont(for: .Light, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            Button("전체 기록 보기") {
                viewModel.showAllRecordsTemporarily()
            }
            .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
            .accessibilityLabel("전체 기록 보기")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appCardSurface()
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    var emptyHistoryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("아직 저장된 산책 기록이 없어요")
                .font(.appFont(for: .SemiBold, size: 14))
            Text("지도에서 산책을 기록하면 목록에 자동으로 추가됩니다.")
                .font(.appFont(for: .Light, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appCardSurface()
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

#Preview {
    WalkListView()
}
