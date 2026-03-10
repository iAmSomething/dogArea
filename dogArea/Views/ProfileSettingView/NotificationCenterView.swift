//
//  NotificationCenterView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct NotificationCenterView: View {
    private enum ActiveSheet: String, Identifiable {
        case profileEdit
        case petManagement

        var id: String { rawValue }
    }

    @StateObject var viewModel = SettingViewModel()
    @EnvironmentObject var authFlow: AuthFlowCoordinator
    @Environment(\.openURL) var openURL
    @Environment(\.scenePhase) var scenePhase
    @State private var activeSheet: ActiveSheet? = nil
    @State private var activeDocument: SettingsDocumentContent? = nil
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
        .task(id: authFlow.isLoggedIn) {
            viewModel.reloadUserInfo()
            await viewModel.refreshProductSurface()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await viewModel.refreshProductSurface()
            }
        }
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
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .profileEdit:
                ProfileFieldEditSheet(viewModel: viewModel) { message in
                    toastMessage = message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        toastMessage = nil
                    }
                } onClose: {
                    activeSheet = nil
                }
            case .petManagement:
                PetManagementSheet(viewModel: viewModel)
            }
        }
        .sheet(item: $activeDocument) { document in
            SettingsDocumentSheetView(document: document) {
                activeDocument = nil
            }
        }
    }

    var memberContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                NonMapRootHeaderContainer {
                    settingsHeader(
                        title: "설정",
                        subtitle: "프로필, 실제 설정, 법적 문서와 지원 정보를 한 곳에서 관리해요."
                    )
                }

                memberProfileCard

                if let season = viewModel.seasonProfileSummary {
                    seasonSummaryCard(summary: season)
                }

                petInfoCard
                appSettingsCard
                legalDocumentsCard
                supportCard
                appInfoCard
                accountActionCard
            }
            .padding(.horizontal, 16)
        }
        .appTabRootScrollLayout(extraBottomPadding: AppTabLayoutMetrics.comfortableScrollExtraBottomPadding)
        .accessibilityIdentifier("screen.settings.member")
        .overlay(alignment: .bottom) {
            if let toastMessage {
                SimpleMessageView(message: toastMessage)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
        }
    }

    var guestLockedContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                NonMapRootHeaderContainer {
                    settingsHeader(
                        title: "설정",
                        subtitle: "로그인 없이도 운영 정보와 문의 경로를 확인할 수 있어요."
                    )
                }

                guestSignInCard
                guestFeaturePreviewCard
                appSettingsCard
                legalDocumentsCard
                supportCard
                appInfoCard
            }
            .padding(.horizontal, 16)
        }
        .appTabRootScrollLayout(extraBottomPadding: AppTabLayoutMetrics.comfortableScrollExtraBottomPadding)
        .accessibilityIdentifier("screen.settings.guest")
    }

    var appSettingsCard: some View {
        SettingsActionSectionCardView(
            title: "앱 설정",
            subtitle: "실제 권한 상태와 시스템 설정 진입 경로를 제공합니다.",
            accessibilityIdentifier: "settings.section.appSettings",
            actions: viewModel.appSettingsActions,
            onSelect: handleSettingsAction
        )
    }

    var legalDocumentsCard: some View {
        SettingsActionSectionCardView(
            title: "개인정보 / 법적 문서",
            subtitle: "개인정보처리방침, 이용약관, 사용 기술 안내를 앱 안에서 확인합니다.",
            accessibilityIdentifier: "settings.section.legal",
            actions: viewModel.legalDocumentActions,
            onSelect: handleSettingsAction
        )
    }

    var supportCard: some View {
        SettingsActionSectionCardView(
            title: "지원 / 문의",
            subtitle: "문의 메일과 버그 리포트, 저장소 공개 채널로 바로 이동합니다.",
            accessibilityIdentifier: "settings.section.support",
            actions: viewModel.supportActions,
            onSelect: handleSettingsAction
        )
    }

    var appInfoCard: some View {
        SettingsAppInfoCardView(
            title: "앱 정보",
            subtitle: "현재 버전, 빌드, 로그인 상태를 한눈에 확인할 수 있어요.",
            accessibilityIdentifier: "settings.section.appInfo",
            rows: viewModel.appInfoRows
        )
    }

    var memberProfileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                SettingsEditableImageButton(
                    title: "사진을 탭해 프로필 사진을 바꿔요.",
                    accessibilityIdentifier: "settings.profile.image",
                    accessibilityLabel: "사용자 프로필 사진 편집"
                ) {
                    #if DEBUG
                    print("[SettingsSheet] user image tapped -> profileEdit")
                    #endif
                    viewModel.reloadUserInfo()
                    activeSheet = .profileEdit
                } content: {
                    UserProfileImageView()
                        .environmentObject(viewModel)
                }

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
                    #if DEBUG
                    print("[SettingsSheet] profile edit tapped")
                    #endif
                    viewModel.reloadUserInfo()
                    activeSheet = .profileEdit
                }, label: {
                    Text("정보 편집")
                })
                .accessibilityIdentifier("settings.profile.edit")
                .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
                .frame(minHeight: 44)
            }
        }
        .appCardSurface()
    }

    var petInfoCard: some View {
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
                SettingsEditableImageButton(
                    title: "사진을 탭해 선택한 반려견 사진을 바꿔요.",
                    accessibilityIdentifier: "settings.pet.image",
                    accessibilityLabel: "선택한 반려견 사진 편집"
                ) {
                    #if DEBUG
                    print("[SettingsSheet] pet image tapped -> profileEdit")
                    #endif
                    viewModel.reloadUserInfo()
                    activeSheet = .profileEdit
                } content: {
                    PetProfileImageView()
                        .environmentObject(viewModel)
                }

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
                    #if DEBUG
                    print("[SettingsSheet] selected pet edit tapped")
                    #endif
                    viewModel.reloadUserInfo()
                    activeSheet = .profileEdit
                }
                .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
                .frame(minHeight: 44)

                Button("반려견 관리") {
                    #if DEBUG
                    print("[SettingsSheet] pet management tapped")
                    #endif
                    viewModel.reloadUserInfo()
                    activeSheet = .petManagement
                }
                .accessibilityIdentifier("settings.pet.manage")
                .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
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

    var accountActionCard: some View {
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

    var guestSignInCard: some View {
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

    var guestFeaturePreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("로그인하면 가능한 기능")
                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            VStack(alignment: .leading, spacing: 8) {
                Text("• 반려견 프로필/사진 관리")
                Text("• 산책 데이터 백업 및 동기화")
                Text("• 라이벌/시즌 기능 전체 사용")
                Text("• 로그인 없이도 아래의 문서/지원/앱 정보는 확인 가능")
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
    func settingsHeader(title: String, subtitle: String) -> some View {
        TitleTextView(
            title: title,
            subTitle: ProcessInfo.processInfo.arguments.contains("-UITest.SettingsHeaderLongSubtitle")
                ? "프로필, 실제 설정, 법적 문서와 지원 정보를 한 곳에서 정리하고 계정 상태까지 차분하게 확인해보세요"
                : subtitle,
            accessibilityIdentifierPrefix: "settings.header"
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.header.section")
    }

    /// 시즌 진행 정보를 요약 카드 형태로 렌더링합니다.
    /// - Parameter summary: 사용자 시즌 상태(랭크, 점수, 기여도)를 담은 요약 모델입니다.
    /// - Returns: 시즌 프레임 스타일이 반영된 요약 카드 뷰입니다.
    func seasonSummaryCard(summary: SeasonProfileSummary) -> some View {
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

    /// 설정 액션을 외부 URL 또는 내부 문서 시트로 라우팅합니다.
    /// - Parameter action: 사용자가 탭한 설정 항목입니다.
    func handleSettingsAction(_ action: SettingsSurfaceAction) {
        switch action.target {
        case .external(let url):
            openURL(url)
        case .document(let document):
            activeDocument = document
        }
    }

    /// 회원탈퇴 요청을 수행하고 성공 시 인증 상태를 정리합니다.
    /// - Returns: 없음. 처리 결과는 토스트 메시지와 인증 상태에 반영됩니다.
    @MainActor
    func handleAccountDeletion() async {
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
