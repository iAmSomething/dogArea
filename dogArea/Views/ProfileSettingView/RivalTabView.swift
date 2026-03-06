import SwiftUI

struct RivalTabView: View {
    @EnvironmentObject private var authFlow: AuthFlowCoordinator
    @StateObject private var viewModel = RivalTabViewModel()
    @State private var isConsentSheetPresented: Bool = false
    @State private var reportTargetAlias: String? = nil
    @State private var isModerationSheetPresented: Bool = false

    let onOpenMap: () -> Void
    let onOpenSettings: () -> Void

    init(
        onOpenMap: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.onOpenMap = onOpenMap
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                TitleTextView(title: "라이벌", subTitle: "근처 산책 열기를 익명으로 확인해요")
                statusBadgeRow
                privacyCard
                hotspotCard
                leaderboardCard
                safetyInfoCard
                footerButtons
            }
            .padding(.top, 8)
        }
        .appTabRootScrollLayout(extraBottomPadding: AppTabLayoutMetrics.comfortableScrollExtraBottomPadding)
        .accessibilityIdentifier("screen.rival.content")
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .onChange(of: authFlow.shouldShowSignIn) { _, shouldShowSignIn in
            if shouldShowSignIn == false {
                viewModel.refreshSessionContext()
            }
        }
        .sheet(isPresented: $isConsentSheetPresented) {
            consentSheet
        }
        .sheet(isPresented: $isModerationSheetPresented) {
            moderationManageSheet
        }
        .confirmationDialog(
            "신고 사유 선택",
            isPresented: Binding(
                get: { reportTargetAlias != nil },
                set: { if $0 == false { reportTargetAlias = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(RivalReportReason.allCases, id: \.rawValue) { reason in
                Button(reason.title) {
                    guard let alias = reportTargetAlias else { return }
                    viewModel.reportAlias(aliasCode: alias, reason: reason)
                    reportTargetAlias = nil
                }
            }
            Button("취소", role: .cancel) {
                reportTargetAlias = nil
            }
        } message: {
            Text("신고 내용은 익명 코드 기준으로 접수되고 정밀 위치는 포함되지 않아요.")
        }
        .overlay(alignment: .top) {
            if let message = viewModel.toastMessage {
                SimpleMessageView(message: message)
                    .padding(.top, 8)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            viewModel.clearToast()
                        }
                    }
            }
        }
    }

    private var statusBadgeRow: some View {
        HStack(spacing: 8) {
            rivalBadge(
                text: viewModel.sharingBadgeText,
                color: viewModel.sharingBadgeColor
            )
            rivalBadge(
                text: viewModel.permissionBadgeText,
                color: viewModel.permissionBadgeColor
            )
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("익명 위치 공유")
                .font(.appFont(for: .SemiBold, size: 20))
            Text("닉네임/강아지명/정밀 좌표는 노출되지 않아요")
                .font(.appFont(for: .Regular, size: 13))
                .foregroundStyle(Color.appTextDarkGray)

            if viewModel.screenState == .guestLocked {
                Button("로그인하고 라이벌 시작") {
                    _ = authFlow.requestAccess(feature: .nearbySocial)
                }
                .accessibilityIdentifier("rival.login.start")
                .buttonStyle(AppFilledButtonStyle(role: .primary))
            } else if viewModel.locationSharingEnabled {
                Button(viewModel.isSharingInFlight ? "처리 중..." : "공유 중지") {
                    viewModel.disableSharing()
                }
                .accessibilityIdentifier("rival.sharing.stop")
                .disabled(viewModel.isSharingInFlight)
                .buttonStyle(AppFilledButtonStyle(role: .neutral))
            } else {
                Button("익명 공유 시작") {
                    switch viewModel.permissionState {
                    case .authorized:
                        isConsentSheetPresented = true
                    case .notDetermined:
                        viewModel.requestLocationPermission()
                    case .denied:
                        viewModel.openSystemSettings()
                    }
                }
                .accessibilityIdentifier("rival.sharing.start")
                .buttonStyle(AppFilledButtonStyle(role: .secondary))
            }
        }
        .padding(12)
        .appCardSurface()
        .padding(.horizontal, 16)
    }

    private var hotspotCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("근처 익명 핫스팟")
                .font(.appFont(for: .SemiBold, size: 20))

            switch viewModel.screenState {
            case .guestLocked:
                Text("회원 가입 후 이용할 수 있어요")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
            case .permissionRequired:
                Text("근처 익명 핫스팟을 보려면 위치 권한이 필요해요")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Button("설정 열기") {
                    viewModel.openSystemSettings()
                }
                .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
            case .consentRequired:
                Text("익명 공유 동의 후 핫스팟을 볼 수 있어요")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
            case .loading:
                ProgressView()
            case .ready, .offlineCached:
                Text("활성 핫스팟 \(viewModel.hotspots.count)개")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Text("최고 강도: \(viewModel.maxIntensityText)")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Text("마지막 업데이트: \(viewModel.lastUpdatedText)")
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
                ForEach(viewModel.hotspotPreviewRows, id: \.title) { row in
                    HStack {
                        Text(row.title)
                            .font(.appFont(for: .Regular, size: 11))
                            .foregroundStyle(Color.appTextDarkGray)
                        Spacer()
                        Text(row.value)
                            .font(.appFont(for: .SemiBold, size: 11))
                            .foregroundStyle(Color.appTextDarkGray)
                    }
                }
                HStack(spacing: 8) {
                    Button(viewModel.isHotspotRefreshing ? "새로고침 중..." : "새로고침") {
                        viewModel.refreshHotspots(force: true)
                    }
                    .disabled(viewModel.isHotspotRefreshing)
                    .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))

                    Button("지도에서 보기") {
                        onOpenMap()
                    }
                    .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                }
            case .offlineEmpty:
                Text("네트워크 연결 후 다시 시도해주세요")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Button("다시 시도") {
                    viewModel.refreshHotspots(force: true)
                }
                .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
            case .errorRetryable:
                Text("일시적으로 불안정해요. 잠시 후 다시 시도해주세요.")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Button("다시 시도") {
                    viewModel.refreshHotspots(force: true)
                }
                .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
            case .empty:
                Text("근처 활성 핫스팟이 아직 없어요")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Button("새로고침") {
                    viewModel.refreshHotspots(force: true)
                }
                .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface()
        .padding(.horizontal, 16)
    }

    private var leaderboardCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("라이벌 비교")
                    .font(.appFont(for: .SemiBold, size: 20))
                Spacer()
                Text(viewModel.compareScope == .rival ? "익명 코드" : "친구 프리뷰")
                    .font(.appFont(for: .SemiBold, size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appTextLightGray.opacity(0.35))
                    .cornerRadius(8)
            }

            Picker("비교 대상", selection: Binding(
                get: { viewModel.compareScope },
                set: { viewModel.setCompareScope($0) }
            )) {
                Text("라이벌").tag(RivalCompareScope.rival)
                Text("친구").tag(RivalCompareScope.friend)
            }
            .pickerStyle(.segmented)

            Picker("비교 기간", selection: Binding(
                get: { viewModel.leaderboardPeriod },
                set: { viewModel.setLeaderboardPeriod($0) }
            )) {
                Text("주간").tag(RivalLeaderboardPeriod.week)
                Text("시즌").tag(RivalLeaderboardPeriod.season)
            }
            .pickerStyle(.segmented)

            switch viewModel.leaderboardState {
            case .guestLocked:
                Text("회원 로그인 후 라이벌 비교를 시작할 수 있어요.")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
            case .permissionRequired:
                Text("위치 권한 허용 후 비교 기능을 사용할 수 있어요.")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
            case .consentRequired:
                Text("익명 공유를 켜면 비교 목록이 열려요.")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
            case .friendPreview:
                Text("친구 비교는 다음 단계에서 제공돼요. 지금은 익명 라이벌 비교만 활성화됩니다.")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
            case .loading:
                ProgressView()
            case .empty:
                Text("아직 표시할 익명 라이벌 데이터가 없어요.")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
            case .errorRetryable:
                Text("리더보드 조회에 실패했어요. 잠시 후 다시 시도해주세요.")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Button("다시 시도") {
                    viewModel.refreshLeaderboard(force: true)
                }
                .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
            case .ready:
                ForEach(viewModel.leaderboardEntries.prefix(6), id: \.id) { entry in
                    leaderboardRow(entry)
                }
            }

            HStack(spacing: 8) {
                Button(viewModel.isLeaderboardRefreshing ? "갱신 중..." : "새로고침") {
                    viewModel.refreshLeaderboard(force: true)
                }
                .disabled(viewModel.isLeaderboardRefreshing || viewModel.compareScope == .friend)
                .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))

                Button("숨김/차단 관리") {
                    isModerationSheetPresented = true
                }
                .accessibilityIdentifier("rival.moderation.manage")
                .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface()
        .padding(.horizontal, 16)
    }

    private var safetyInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("안전 안내")
                .font(.appFont(for: .SemiBold, size: 16))
            Text("비회원에게는 300m 저해상도 격자 요약만 노출되며, 정밀 좌표/실시간 점 위치는 공개되지 않아요.")
                .font(.appFont(for: .Regular, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            Text("공유 OFF는 앱에서 즉시 반영되고 서버 반영은 최대 30초 내 동기화를 재시도해요. 철회/탈퇴 데이터는 7일 보존 후 삭제돼요.")
                .font(.appFont(for: .Regular, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface()
        .padding(.horizontal, 16)
    }

    private var footerButtons: some View {
        HStack(spacing: 8) {
            Button("설정에서 상세 관리") {
                onOpenSettings()
            }
            .accessibilityIdentifier("rival.footer.openSettings")
            .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))

            Button("지도 이동") {
                onOpenMap()
            }
            .accessibilityIdentifier("rival.footer.openMap")
            .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
        }
    }

    private var consentSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("익명 위치 공유 동의")
                .font(.appFont(for: .SemiBold, size: 22))
            Text("닉네임/강아지명/정밀 좌표는 표시되지 않고, 300m 저해상도 격자 요약으로만 노출돼요.")
                .font(.appFont(for: .Regular, size: 13))
                .foregroundStyle(Color.appTextDarkGray)
            Text("언제든 라이벌 탭에서 공유를 끌 수 있고, OFF 전환은 최대 30초 내 서버/지도에 반영돼요.")
                .font(.appFont(for: .Regular, size: 13))
                .foregroundStyle(Color.appTextDarkGray)

            HStack(spacing: 10) {
                Button("취소") {
                    isConsentSheetPresented = false
                }
                .accessibilityIdentifier("sheet.rival.consent.cancel")
                .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))

                Button(viewModel.isSharingInFlight ? "처리 중..." : "동의하고 시작") {
                    isConsentSheetPresented = false
                    viewModel.enableSharingWithConsent()
                }
                .accessibilityIdentifier("sheet.rival.consent.confirm")
                .disabled(viewModel.isSharingInFlight)
                .buttonStyle(AppFilledButtonStyle(role: .primary, fillsWidth: false))
            }
            Spacer()
        }
        .padding(16)
        .presentationDetents([.medium])
    }

    private var moderationManageSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("숨김/차단 관리")
                .font(.appFont(for: .SemiBold, size: 22))
            Text("즉시 반영되며, 언제든 다시 해제할 수 있어요.")
                .font(.appFont(for: .Regular, size: 12))
                .foregroundStyle(Color.appTextDarkGray)

            if viewModel.hiddenAliases.isEmpty && viewModel.blockedAliases.isEmpty {
                Text("현재 숨김/차단된 익명 코드가 없어요.")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
            }

            if viewModel.hiddenAliases.isEmpty == false {
                VStack(alignment: .leading, spacing: 6) {
                    Text("숨김")
                        .font(.appFont(for: .SemiBold, size: 14))
                    ForEach(viewModel.hiddenAliases, id: \.self) { alias in
                        HStack {
                            Text(alias)
                                .font(.appFont(for: .Regular, size: 12))
                            Spacer()
                            Button("해제") {
                                viewModel.unhideAlias(aliasCode: alias)
                            }
                            .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
                        }
                    }
                }
            }

            if viewModel.blockedAliases.isEmpty == false {
                VStack(alignment: .leading, spacing: 6) {
                    Text("차단")
                        .font(.appFont(for: .SemiBold, size: 14))
                    ForEach(viewModel.blockedAliases, id: \.self) { alias in
                        HStack {
                            Text(alias)
                                .font(.appFont(for: .Regular, size: 12))
                            Spacer()
                            Button("해제") {
                                viewModel.unblockAlias(aliasCode: alias)
                            }
                            .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .presentationDetents([.medium, .large])
    }

    private func leaderboardRow(_ entry: RivalLeaderboardEntryDTO) -> some View {
        HStack(spacing: 8) {
            Text("#\(entry.rank)")
                .font(.appFont(for: .SemiBold, size: 14))
                .foregroundStyle(Color.appTextDarkGray)
                .frame(width: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.aliasCode + (entry.isMe ? " (나)" : ""))
                    .font(.appFont(for: .SemiBold, size: 13))
                Text("점수 구간 \(entry.scoreBucket)")
                    .font(.appFont(for: .Regular, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
            }
            Spacer()
            Text(entry.effectiveLeague.uppercased())
                .font(.appFont(for: .SemiBold, size: 10))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(leagueBadgeColor(entry.effectiveLeague).opacity(0.24))
                .cornerRadius(8)
            Menu {
                Button("신고") {
                    reportTargetAlias = entry.aliasCode
                }
                Button("차단") {
                    viewModel.blockAlias(aliasCode: entry.aliasCode)
                }
                Button("숨기기") {
                    viewModel.hideAlias(aliasCode: entry.aliasCode)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.appTextDarkGray)
            }
        }
        .padding(.vertical, 4)
    }

    private func leagueBadgeColor(_ league: String) -> Color {
        switch league.lowercased() {
        case "platinum":
            return Color.appRed
        case "gold":
            return Color.appYellow
        case "silver":
            return Color.appTextLightGray
        case "bronze":
            return Color.appPeach
        default:
            return Color.appGreen
        }
    }

    private func rivalBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.appFont(for: .SemiBold, size: 11))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.25))
            .cornerRadius(8)
    }
}
