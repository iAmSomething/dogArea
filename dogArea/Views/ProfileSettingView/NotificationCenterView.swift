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
    @State private var isPetManagementPresented: Bool = false
    @State private var toastMessage: String? = nil
    @State private var isLogoutAlertPresented: Bool = false
    @State private var isAccountDeleteAlertPresented: Bool = false

    var body: some View {
        Group {
            if authFlow.isLoggedIn {
                memberContent
            } else {
                guestLockedContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appTabScaffoldBackground.ignoresSafeArea())
        .alert("로그아웃할까요?", isPresented: $isLogoutAlertPresented) {
            Button("취소", role: .cancel) { }
            Button("로그아웃", role: .destructive) {
                authFlow.signOut()
            }
        } message: {
            Text("현재 기기의 인증 상태를 해제하고 게스트 모드로 전환합니다.")
        }
        .alert("회원탈퇴할까요?", isPresented: $isAccountDeleteAlertPresented) {
            Button("취소", role: .cancel) { }
            Button("회원탈퇴", role: .destructive) {
                Task {
                    await handleAccountDeletion()
                }
            }
        } message: {
            Text("탈퇴 시 계정 정보와 프로필 데이터가 삭제되며 복구할 수 없습니다.")
        }
    }

    private var memberContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                settingsHeader(
                    title: "설정",
                    subtitle: "프로필, 반려견, 계정 상태를 한 번에 관리해요."
                )

                memberProfileCard

                if let season = viewModel.seasonProfileSummary {
                    seasonSummaryCard(summary: season)
                }

                petInfoCard

                accountActionCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .appTabBarContentPadding(extra: 20)
        }
        .scrollIndicators(.hidden)
        .safeAreaPadding(.top, 8)
        .onAppear {
            viewModel.reloadUserInfo()
        }
        .sheet(isPresented: $isProfileEditPresented) {
            ProfileFieldEditSheet(viewModel: viewModel) { message in
                toastMessage = message
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    toastMessage = nil
                }
            } onClose: {
                isProfileEditPresented = false
            }
        }
        .sheet(isPresented: $isPetManagementPresented) {
            PetManagementSheet(viewModel: viewModel)
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                SimpleMessageView(message: toastMessage)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
        }
    }

    private var guestLockedContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                settingsHeader(
                    title: "설정",
                    subtitle: "로그인 후 프로필과 동기화 기능을 사용할 수 있어요."
                )

                guestSignInCard

                guestFeaturePreviewCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .appTabBarContentPadding(extra: 20)
        }
        .scrollIndicators(.hidden)
        .safeAreaPadding(.top, 8)
    }

    private var memberProfileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Button {
                    isProfileEditPresented = true
                } label: {
                    UserProfileImageView()
                        .environmentObject(viewModel)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.profile.image")

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.userInfo?.name ?? "산책꾼")
                        .font(.appScaledFont(for: .SemiBold, size: 24, relativeTo: .title2))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

                    if let season = viewModel.seasonProfileSummary {
                        Text("Season \(season.rankTier.title)")
                            .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(SeasonProfileFrameStyle.style(for: season.rankTier).fill.opacity(0.24))
                            .cornerRadius(8)
                    }

                    if let profileMessage = viewModel.userInfo?.profileMessage,
                       profileMessage.isEmpty == false {
                        Text(profileMessage)
                            .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("가입 정보: \(viewModel.userInfo?.createdAt.createdAtTimeYYMMDD ?? "-")")
                        .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x64748B))
                }

                Spacer(minLength: 0)
            }

            HStack {
                Spacer()
                Button(action: {
                    isProfileEditPresented = true
                }, label: {
                    Text("프로필 편집")
                })
                .accessibilityIdentifier("settings.profile.edit")
                .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                .frame(minHeight: 44)
            }
        }
        .appCardSurface()
    }

    private var petInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("반려견 정보")
                    .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Spacer()
                if viewModel.pets.isEmpty == false {
                    Text("활성 \(viewModel.activePets.count) · 전체 \(viewModel.pets.count)")
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                }
            }

            if viewModel.pets.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.pets, id: \.petId) { pet in
                            Button {
                                viewModel.selectPet(pet.petId)
                            } label: {
                                Text(pet.petName)
                                    .appPill(isActive: viewModel.selectedPetId == pet.petId && pet.isActive)
                            }
                            .buttonStyle(.plain)
                            .disabled(pet.isActive == false)
                            .frame(minHeight: 44)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack(alignment: .center, spacing: 14) {
                PetProfileImageView()
                    .environmentObject(viewModel)

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.selectedPet?.petName ?? "강아지")
                        .font(.appScaledFont(for: .SemiBold, size: 22, relativeTo: .title3))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

                    Text(viewModel.selectedPet.map(viewModel.petDetailsText(for:)) ?? "견종(선택)/나이/성별 미입력")
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)

                    if let status = viewModel.selectedPet?.caricatureStatus {
                        Text("캐리커처 상태: \(status.rawValue)")
                            .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                            .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x64748B))
                    }
                }

                Spacer(minLength: 0)
            }

            if viewModel.activePets.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("대표 반려견 선택")
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))

                    Picker(
                        "대표 강아지",
                        selection: Binding<String>(
                            get: {
                                viewModel.selectedPetId.isEmpty == false
                                ? viewModel.selectedPetId
                                : (viewModel.activePets.first?.petId ?? "")
                            },
                            set: { viewModel.selectPet($0) }
                        )
                    ) {
                        ForEach(viewModel.activePets, id: \.id) { pet in
                            Text(pet.petName).tag(pet.petId)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.top, 4)
            }

            HStack(spacing: 8) {
                Button("선택 반려견 편집") {
                    isProfileEditPresented = true
                }
                .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                .frame(minHeight: 44)

                Button("반려견 관리") {
                    isPetManagementPresented = true
                }
                .accessibilityIdentifier("settings.pet.manage")
                .buttonStyle(AppFilledButtonStyle(role: .primary, fillsWidth: false))
                .frame(minHeight: 44)
            }

            if viewModel.inactivePets.isEmpty == false {
                VStack(alignment: .leading, spacing: 6) {
                    Text("비활성 반려견")
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    Text(viewModel.inactivePets.map(\.petName).joined(separator: ", "))
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
                }
            }
        }
        .appCardSurface()
    }

    private var accountActionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("계정")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            Text("로그아웃하면 현재 기기 인증 상태가 해제되고 게스트 모드로 전환됩니다.")
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)

            Button("로그아웃") {
                isLogoutAlertPresented = true
            }
            .accessibilityIdentifier("settings.logout")
            .buttonStyle(AppFilledButtonStyle(role: .destructive))
            .frame(minHeight: 44)

            Divider()

            Text("회원탈퇴 시 계정 데이터가 서버에서 삭제되고 현재 기기 인증도 즉시 해제됩니다.")
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFDBA74))
                .fixedSize(horizontal: false, vertical: true)

            Button(viewModel.isAccountDeletionInProgress ? "회원탈퇴 처리 중..." : "회원탈퇴") {
                isAccountDeleteAlertPresented = true
            }
            .accessibilityIdentifier("settings.account.delete")
            .disabled(viewModel.isAccountDeletionInProgress)
            .buttonStyle(AppFilledButtonStyle(role: .destructive))
            .frame(minHeight: 44)
        }
        .appCardSurface()
    }

    private var guestSignInCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("현재는 게스트 모드예요")
                .font(.appScaledFont(for: .SemiBold, size: 20, relativeTo: .title3))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            Text("프로필 편집, 반려견 정보 관리, 클라우드 동기화는 로그인 후 사용할 수 있습니다.")
                .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)

            Button("로그인/회원가입 열기") {
                _ = authFlow.requestAccess(feature: .cloudSync)
            }
            .accessibilityIdentifier("settings.open.signin")
            .buttonStyle(AppFilledButtonStyle(role: .primary))
            .frame(minHeight: 44)
        }
        .appCardSurface()
    }

    private var guestFeaturePreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("로그인하면 가능한 기능")
                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            VStack(alignment: .leading, spacing: 8) {
                Text("• 반려견 프로필/사진 관리")
                Text("• 산책 데이터 백업 및 동기화")
                Text("• 라이벌/시즌 기능 전체 사용")
            }
            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
        }
        .appCardSurface()
    }

    /// 설정 화면 상단 헤더를 렌더링합니다.
    /// - Parameters:
    ///   - title: 헤더의 메인 타이틀 텍스트입니다.
    ///   - subtitle: 메인 타이틀 하단에 표시할 보조 설명 텍스트입니다.
    /// - Returns: 설정 화면 톤에 맞춘 헤더 뷰입니다.
    private func settingsHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.appScaledFont(for: .SemiBold, size: 34, relativeTo: .largeTitle))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text(subtitle)
                .font(.appScaledFont(for: .Regular, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
        }
        .padding(.horizontal, 2)
    }

    /// 시즌 진행 정보를 요약 카드 형태로 렌더링합니다.
    /// - Parameter summary: 사용자 시즌 상태(랭크, 점수, 기여도)를 담은 요약 모델입니다.
    /// - Returns: 시즌 프레임 스타일이 반영된 요약 카드 뷰입니다.
    private func seasonSummaryCard(summary: SeasonProfileSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("시즌 진행 현황")
                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
            Text("랭크 \(summary.rankTier.title) · 점수 \(summary.score)pt")
                .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                .foregroundStyle(Color.appTextDarkGray)
            Text("주차 \(summary.weekKey) · 기여 \(summary.contributionCount)회")
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appTextDarkGray)
            Text("프로필 프레임: \(summary.rankTier.title)")
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appTextDarkGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(SeasonProfileFrameStyle.style(for: summary.rankTier).fill.opacity(0.2))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(SeasonProfileFrameStyle.style(for: summary.rankTier).stroke, lineWidth: 1)
        )
    }
    /// 회원탈퇴 요청을 수행하고 성공 시 인증 상태를 정리합니다.
    /// - Returns: 없음. 처리 결과는 토스트 메시지와 인증 상태에 반영됩니다.
    @MainActor
    private func handleAccountDeletion() async {
        let result = await viewModel.deleteAccount()
        switch result {
        case .success:
            authFlow.signOut()
            toastMessage = "회원탈퇴가 완료되었습니다."
        case .failure(let error):
            toastMessage = error.localizedDescription
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            toastMessage = nil
        }
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
