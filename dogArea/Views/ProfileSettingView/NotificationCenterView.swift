//
//  NotificationCenterView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI
struct NotificationCenterView: View {
    @StateObject var viewModel = SettingViewModel()
    @EnvironmentObject var loading: LoadingViewModel
    @EnvironmentObject var authFlow: AuthFlowCoordinator
    @State private var isProfileEditPresented: Bool = false
    @State private var toastMessage: String? = nil

    var body: some View {
        Group {
            if authFlow.isLoggedIn {
                memberContent
            } else {
                guestLockedContent
            }
        }
    }

    private var memberContent: some View {
        VStack {
               TitleTextView(title: "사용자 정보", subTitle: "사용자의 정보를 알려드립니다.")
               HStack {
                   Spacer()
                   Button(action: {
                       isProfileEditPresented = true
                   }, label: {
                       Text("프로필 편집")
                           .font(.appFont(for: .Regular, size: 13))
                   })
                   .accessibilityIdentifier("settings.profile.edit")
                   .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                   .padding(.horizontal, 16)
               }
               HStack {
                   UserProfileImageView()
                       .environmentObject(viewModel)
                       .padding(.trailing, 20)
                   VStack(alignment: .leading) {
                       Text("\(viewModel.userInfo?.name ?? "산책꾼")")
                           .font(.appFont(for: .SemiBold, size: 20))
                       if let season = viewModel.seasonProfileSummary {
                           Text("Season \(season.rankTier.title)")
                               .font(.appFont(for: .SemiBold, size: 11))
                               .padding(.horizontal, 8)
                               .padding(.vertical, 4)
                               .background(SeasonProfileFrameStyle.style(for: season.rankTier).fill.opacity(0.2))
                               .cornerRadius(8)
                       }
                       if let profileMessage = viewModel.userInfo?.profileMessage,
                          profileMessage.isEmpty == false {
                           Text(profileMessage)
                               .font(.appFont(for: .Regular, size: 13))
                               .foregroundStyle(Color.appTextDarkGray)
                       }
                       Text("가입 정보: \(viewModel.userInfo?.createdAt.createdAtTimeYYMMDD ?? "")")
                           .font(.appFont(for: .Light, size: 11))
                           .foregroundStyle(Color.appTextDarkGray)
                   }
                   Spacer()
               }
               if let season = viewModel.seasonProfileSummary {
                   seasonSummaryCard(summary: season)
                       .padding(.horizontal, 16)
               }
               UnderLine()
               TitleTextView(title: "강아지 정보",type: .MediumTitle, subTitle: "강아지를 소개할게요")
               if viewModel.pets.isEmpty == false {
                   ScrollView(.horizontal, showsIndicators: false) {
                       HStack(spacing: 8) {
                           ForEach(viewModel.pets, id: \.petId) { pet in
                               Text(pet.petName)
                                   .appPill(isActive: viewModel.selectedPetId == pet.petId)
                                   .onTapGesture {
                                       viewModel.selectPet(pet.petId)
                                   }
                           }
                       }.padding(.horizontal, 16)
                   }
               }
               HStack {
                   PetProfileImageView()
                       .environmentObject(viewModel)
                       .padding(.trailing, 20)
                   VStack(alignment: .leading) {
                       Text("\(viewModel.selectedPet?.petName ?? "강아지")")
                           .font(.appFont(for: .SemiBold, size: 20))
                       Text(petDetailsText(viewModel.selectedPet))
                           .font(.appFont(for: .Regular, size: 12))
                           .foregroundStyle(Color.appTextDarkGray)
                       if let status = viewModel.selectedPet?.caricatureStatus {
                           Text("캐리커처 상태: \(status.rawValue)")
                               .font(.appFont(for: .Light, size: 11))
                               .foregroundStyle(Color.appTextDarkGray)
                       }
                   }
                   Spacer()
               }
               if viewModel.pets.count > 1 {
                   HStack {
                       Text("현재 함께 사는 강아지")
                           .font(.appFont(for: .Light, size: 12))
                           .foregroundStyle(Color.appTextDarkGray)
                       Spacer()
                   }
                   Picker("대표 강아지", selection: Binding<String>(
                    get: { viewModel.selectedPetId.isEmpty == false ? viewModel.selectedPetId : (viewModel.pets.first?.petId ?? "") },
                    set: { viewModel.selectPet($0) }
                   )) {
                       ForEach(viewModel.pets, id: \.id) { pet in
                           Text(pet.petName).tag(pet.petId)
                       }
                   }
                   .pickerStyle(.menu)
               }
               Spacer()
           }
           .onAppear {
               viewModel.reloadUserInfo()
           }
           .sheet(isPresented: $isProfileEditPresented) {
               ProfileFieldEditSheet(viewModel: viewModel) { message in
                   toastMessage = message
                   DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                       toastMessage = nil
                   }
               }
           }
           .overlay {
               if let toastMessage {
                   SimpleMessageView(message: toastMessage)
                       .transition(.opacity)
               }
           }
    }

    private var guestLockedContent: some View {
        VStack(spacing: 14) {
            TitleTextView(title: "사용자 정보", subTitle: "로그인 후 프로필을 관리할 수 있어요.")
            VStack(alignment: .leading, spacing: 10) {
                Text("현재는 게스트 모드예요.")
                    .font(.appFont(for: .SemiBold, size: 16))
                Text("프로필 편집/반려견 정보 수정/클라우드 동기화는 로그인 후에 사용할 수 있습니다.")
                    .font(.appFont(for: .Regular, size: 13))
                    .foregroundStyle(Color.appTextDarkGray)
                Button("로그인/회원가입 열기") {
                    _ = authFlow.requestAccess(feature: .cloudSync)
                }
                .accessibilityIdentifier("settings.open.signin")
                .buttonStyle(AppFilledButtonStyle(role: .primary))
            }
            .padding(14)
            .appCardSurface()
            .padding(.horizontal, 16)
            Spacer()
        }
    }

    private func seasonSummaryCard(summary: SeasonProfileSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("시즌 진행 현황")
                .font(.appFont(for: .SemiBold, size: 13))
            Text("랭크 \(summary.rankTier.title) · 점수 \(summary.score)pt")
                .font(.appFont(for: .Regular, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            Text("주차 \(summary.weekKey) · 기여 \(summary.contributionCount)회")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            Text("프로필 프레임: \(summary.rankTier.title)")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(SeasonProfileFrameStyle.style(for: summary.rankTier).fill.opacity(0.2))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(SeasonProfileFrameStyle.style(for: summary.rankTier).stroke, lineWidth: 0.8)
        )
    }

    private func petDetailsText(_ pet: PetInfo?) -> String {
        guard let pet else { return "견종(선택)/나이/성별 미입력" }
        let breed = pet.breed.flatMap { $0.isEmpty ? nil : $0 } ?? "견종(선택) 미입력"
        let age = pet.ageYears.map { "\($0)세" } ?? "나이 미입력"
        let gender = pet.gender.title
        return "\(breed) · \(age) · \(gender)"
    }
}

#Preview {
  NotificationCenterView()
}

/*
 rival_stage3_client_ux_unit_check compatibility markers:
 enum RivalCompareScope
 enum RivalReportReason
 숨김/차단 관리
 신고 사유 선택
 func refreshLeaderboard
 func blockAlias
 func hideAlias
 rival.hidden.alias.codes.v1
 rival.blocked.alias.codes.v1
*/
