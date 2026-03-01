import SwiftUI
import Kingfisher
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

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
            .padding(.bottom, 24)
        }
        .background(Color.appYellowPale.opacity(0.35))
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
            Text("비교 지도는 geohash7 격자 단위로 집계되며, 정밀 이동 경로/닉네임/강아지명은 노출되지 않아요.")
                .font(.appFont(for: .Regular, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            Text("신고·차단·숨김은 즉시 UI에 반영되고, 공유를 끄면 비교 화면이 바로 비활성화됩니다.")
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
            .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))

            Button("지도 이동") {
                onOpenMap()
            }
            .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
        }
    }

    private var consentSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("익명 위치 공유 동의")
                .font(.appFont(for: .SemiBold, size: 22))
            Text("닉네임/강아지명/정밀 좌표는 표시되지 않고, 10분 TTL 집계로만 사용돼요.")
                .font(.appFont(for: .Regular, size: 13))
                .foregroundStyle(Color.appTextDarkGray)
            Text("언제든 라이벌 탭에서 공유를 끌 수 있어요.")
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

@MainActor
final class RivalTabViewModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    struct HotspotPreviewRow {
        let title: String
        let value: String
    }

    enum PermissionState {
        case notDetermined
        case authorized
        case denied
    }

    enum ScreenState {
        case guestLocked
        case permissionRequired
        case consentRequired
        case loading
        case ready
        case empty
        case offlineCached
        case offlineEmpty
        case errorRetryable
    }

    enum LeaderboardState {
        case guestLocked
        case permissionRequired
        case consentRequired
        case friendPreview
        case loading
        case ready
        case empty
        case errorRetryable
    }

    @Published private(set) var permissionState: PermissionState = .notDetermined
    @Published private(set) var screenState: ScreenState = .guestLocked
    @Published private(set) var leaderboardState: LeaderboardState = .guestLocked
    @Published private(set) var locationSharingEnabled: Bool = false
    @Published private(set) var hotspots: [NearbyHotspotDTO] = []
    @Published private(set) var leaderboardEntries: [RivalLeaderboardEntryDTO] = []
    @Published private(set) var hiddenAliases: [String] = []
    @Published private(set) var blockedAliases: [String] = []
    @Published private(set) var hotspotPreviewRows: [HotspotPreviewRow] = []
    @Published private(set) var isSharingInFlight: Bool = false
    @Published private(set) var isHotspotRefreshing: Bool = false
    @Published private(set) var isLeaderboardRefreshing: Bool = false
    @Published private(set) var lastUpdatedText: String = "-"
    @Published private(set) var maxIntensityText: String = "없음"
    @Published private(set) var compareScope: RivalCompareScope = .rival
    @Published private(set) var leaderboardPeriod: RivalLeaderboardPeriod = .week
    @Published var toastMessage: String? = nil

    private let nearbyService: NearbyPresenceServiceProtocol
    private let rivalLeagueService: RivalLeagueServiceProtocol
    private let preferenceStore: MapPreferenceStoreProtocol
    private let locationManager: CLLocationManager
    private let authSessionStore: AuthSessionStoreProtocol
    private let sessionProvider: () -> AppSessionState
    private let locationSharingKey = "nearby.locationSharingEnabled.v1"
    private let hiddenAliasKey = "rival.hidden.alias.codes.v1"
    private let blockedAliasKey = "rival.blocked.alias.codes.v1"
    private let moderationLogKey = "rival.moderation.logs.v1"
    private var pollingTimer: Timer? = nil
    private var lastRefreshAt: Date = .distantPast
    private var lastLeaderboardRefreshAt: Date = .distantPast
    private var latestRawLeaderboardEntries: [RivalLeaderboardEntryDTO] = []

    /// 라이벌 탭 상태를 제어하는 뷰모델을 초기화합니다.
    init(
        nearbyService: NearbyPresenceServiceProtocol = NearbyPresenceService(),
        rivalLeagueService: RivalLeagueServiceProtocol = RivalLeagueService(),
        preferenceStore: MapPreferenceStoreProtocol = DefaultMapPreferenceStore.shared,
        locationManager: CLLocationManager = CLLocationManager(),
        authSessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared,
        sessionProvider: @escaping () -> AppSessionState = { AppFeatureGate.currentSession() }
    ) {
        self.nearbyService = nearbyService
        self.rivalLeagueService = rivalLeagueService
        self.preferenceStore = preferenceStore
        self.locationManager = locationManager
        self.authSessionStore = authSessionStore
        self.sessionProvider = sessionProvider
        super.init()
    }

    deinit {
        pollingTimer?.invalidate()
    }

    /// 탭 진입 시 권한/공유 상태를 불러오고 폴링을 시작합니다.
    func start() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
        loadModerationPreferences()
        refreshSessionContext()
        startPollingIfNeeded()
    }

    /// 탭 이탈 시 폴링/위치 업데이트를 중단합니다.
    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        locationManager.stopUpdatingLocation()
    }

    /// 로그인/로그아웃 직후 세션 컨텍스트를 다시 읽고 UI 상태를 즉시 갱신합니다.
    func refreshSessionContext() {
        locationSharingEnabled = preferenceStore.bool(forKey: locationSharingKey, default: false)
        loadModerationPreferences()
        updatePermissionState()
        refreshViewState()
        refreshHotspots(force: true)
        refreshLeaderboard(force: true)
    }

    /// 위치 권한 요청을 수행합니다.
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 동의 시트 완료 후 익명 공유를 활성화합니다.
    func enableSharingWithConsent() {
        guard currentUserId != nil else {
            showToast("회원 전용 기능입니다. 로그인 후 다시 시도해주세요.")
            refreshViewState()
            return
        }

        isSharingInFlight = true
        Task {
            defer { isSharingInFlight = false }
            do {
                try await nearbyService.setVisibility(userId: currentUserId ?? "", enabled: true)
                preferenceStore.set(true, forKey: locationSharingKey)
                locationSharingEnabled = true
                showToast("익명 공유가 시작됐어요")
                refreshViewState()
                refreshHotspots(force: true)
                refreshLeaderboard(force: true)
            } catch {
                preferenceStore.set(false, forKey: locationSharingKey)
                locationSharingEnabled = false
                refreshViewState()
                showToast(visibilityFailureMessage(from: error))
            }
        }
    }

    /// 익명 공유를 비활성화하고 핫스팟을 초기화합니다.
    func disableSharing() {
        guard let userId = currentUserId else {
            preferenceStore.set(false, forKey: locationSharingKey)
            locationSharingEnabled = false
            hotspots = []
            refreshViewState()
            return
        }

        isSharingInFlight = true
        let previous = locationSharingEnabled
        preferenceStore.set(false, forKey: locationSharingKey)
        locationSharingEnabled = false
        hotspots = []
        leaderboardEntries = []
        latestRawLeaderboardEntries = []
        refreshViewState()
        showToast("익명 공유를 중지했어요")

        Task {
            defer { isSharingInFlight = false }
            do {
                try await nearbyService.setVisibility(userId: userId, enabled: false)
            } catch {
                preferenceStore.set(previous, forKey: locationSharingKey)
                locationSharingEnabled = previous
                refreshViewState()
                showToast(visibilityFailureMessage(from: error))
            }
        }
    }

    /// 핫스팟을 새로 조회하고 카드 상태를 갱신합니다.
    func refreshHotspots(force: Bool = false) {
        guard screenState != .guestLocked else { return }
        guard permissionState == .authorized else {
            refreshViewState()
            return
        }
        guard locationSharingEnabled else {
            refreshViewState()
            return
        }
        guard let coordinate = locationManager.location?.coordinate else {
            screenState = hotspots.isEmpty ? .empty : .ready
            return
        }

        if force == false && Date().timeIntervalSince(lastRefreshAt) < 1.0 {
            return
        }

        isHotspotRefreshing = true
        if hotspots.isEmpty {
            screenState = .loading
        }
        let userId = currentUserId
        Task {
            defer { isHotspotRefreshing = false }
            do {
                let fetched = try await nearbyService.getHotspots(
                    userId: userId,
                    centerLatitude: coordinate.latitude,
                    centerLongitude: coordinate.longitude,
                    radiusKm: 1.0
                )
                hotspots = fetched
                lastRefreshAt = Date()
                updateHotspotSummary()
                if fetched.isEmpty {
                    screenState = .empty
                } else {
                    screenState = .ready
                }
            } catch {
                if isConnectivityError(error) {
                    screenState = hotspots.isEmpty ? .offlineEmpty : .offlineCached
                } else {
                    screenState = .errorRetryable
                }
            }
        }
    }

    /// 리더보드의 비교 범위를 전환합니다.
    func setCompareScope(_ scope: RivalCompareScope) {
        compareScope = scope
        refreshLeaderboard(force: true)
    }

    /// 리더보드의 비교 기간(주간/시즌)을 전환합니다.
    func setLeaderboardPeriod(_ period: RivalLeaderboardPeriod) {
        leaderboardPeriod = period
        refreshLeaderboard(force: true)
    }

    /// 익명 리더보드를 조회하고 숨김/차단 필터를 적용합니다.
    func refreshLeaderboard(force: Bool = false) {
        guard compareScope == .rival else {
            leaderboardState = .friendPreview
            leaderboardEntries = []
            return
        }
        guard currentUserId != nil else {
            leaderboardState = .guestLocked
            leaderboardEntries = []
            return
        }
        guard permissionState == .authorized else {
            leaderboardState = .permissionRequired
            leaderboardEntries = []
            return
        }
        guard locationSharingEnabled else {
            leaderboardState = .consentRequired
            leaderboardEntries = []
            return
        }
        if force == false && Date().timeIntervalSince(lastLeaderboardRefreshAt) < 1.0 {
            return
        }

        isLeaderboardRefreshing = true
        if leaderboardEntries.isEmpty {
            leaderboardState = .loading
        }
        Task {
            defer { isLeaderboardRefreshing = false }
            do {
                let rows = try await rivalLeagueService.fetchLeaderboard(period: leaderboardPeriod, topN: 20)
                latestRawLeaderboardEntries = rows
                lastLeaderboardRefreshAt = Date()
                applyLeaderboardModerationFilter()
            } catch {
                leaderboardState = .errorRetryable
            }
        }
    }

    /// 익명 코드 숨김을 적용하고 즉시 목록에서 제거합니다.
    func hideAlias(aliasCode: String) {
        var next = Set(hiddenAliases)
        next.insert(aliasCode)
        hiddenAliases = next.sorted()
        persistModerationPreferences()
        appendModerationLog(action: "hide", aliasCode: aliasCode, reason: nil)
        applyLeaderboardModerationFilter()
        showToast("\(aliasCode) 숨김 처리됐어요")
    }

    /// 익명 코드 차단을 적용하고 즉시 목록에서 제거합니다.
    func blockAlias(aliasCode: String) {
        var blocked = Set(blockedAliases)
        blocked.insert(aliasCode)
        blockedAliases = blocked.sorted()
        var hidden = Set(hiddenAliases)
        hidden.insert(aliasCode)
        hiddenAliases = hidden.sorted()
        persistModerationPreferences()
        appendModerationLog(action: "block", aliasCode: aliasCode, reason: nil)
        applyLeaderboardModerationFilter()
        showToast("\(aliasCode) 차단 처리됐어요")
    }

    /// 숨김된 익명 코드를 다시 표시 대상으로 복구합니다.
    func unhideAlias(aliasCode: String) {
        hiddenAliases.removeAll { $0 == aliasCode }
        persistModerationPreferences()
        applyLeaderboardModerationFilter()
    }

    /// 차단된 익명 코드를 다시 표시 대상으로 복구합니다.
    func unblockAlias(aliasCode: String) {
        blockedAliases.removeAll { $0 == aliasCode }
        hiddenAliases.removeAll { $0 == aliasCode }
        persistModerationPreferences()
        applyLeaderboardModerationFilter()
    }

    /// 신고 사유를 로컬 로그에 남기고 중복 신고를 방지합니다.
    func reportAlias(aliasCode: String, reason: RivalReportReason) {
        appendModerationLog(action: "report", aliasCode: aliasCode, reason: reason.rawValue)
        showToast("\(aliasCode) 신고가 접수됐어요")
    }

    /// 권한 안내 카드에서 시스템 설정 화면을 엽니다.
    func openSystemSettings() {
#if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
#endif
    }

    /// 짧은 사용자 피드백 메시지를 노출합니다.
    func showToast(_ message: String) {
        toastMessage = message
    }

    /// 노출 중인 토스트를 제거합니다.
    func clearToast() {
        toastMessage = nil
    }

    var sharingBadgeText: String {
        locationSharingEnabled ? "공유 중" : "비공개"
    }

    var sharingBadgeColor: Color {
        locationSharingEnabled ? Color.appGreen : Color.appTextLightGray
    }

    var permissionBadgeText: String {
        guard currentUserId != nil else { return "로그인 필요" }
        return permissionState == .authorized ? "위치 허용" : "권한 필요"
    }

    var permissionBadgeColor: Color {
        guard currentUserId != nil else { return Color.appTextLightGray }
        return permissionState == .authorized ? Color.appGreen : Color.appRed
    }

    private var currentUserId: String? {
        if let authUserId = authSessionStore.currentIdentity()?.userId,
           let canonical = authUserId.canonicalUUIDString {
            return canonical
        }
        guard case .member(let userId) = sessionProvider(),
              let canonical = userId.canonicalUUIDString else {
            return nil
        }
        return canonical
    }

    /// 권한 상태를 iOS 시스템 값에서 앱 상태로 변환합니다.
    private func updatePermissionState() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            permissionState = .authorized
        case .notDetermined:
            permissionState = .notDetermined
        case .denied, .restricted:
            permissionState = .denied
        @unknown default:
            permissionState = .denied
        }
    }

    /// 인증/권한/공유 상태를 바탕으로 라이벌 화면 상태를 결정합니다.
    private func refreshViewState() {
        guard currentUserId != nil else {
            screenState = .guestLocked
            leaderboardState = .guestLocked
            return
        }
        guard permissionState == .authorized else {
            screenState = .permissionRequired
            leaderboardState = .permissionRequired
            return
        }
        guard locationSharingEnabled else {
            screenState = .consentRequired
            leaderboardState = .consentRequired
            return
        }
        if hotspots.isEmpty {
            screenState = .empty
        } else {
            screenState = .ready
        }
        if compareScope == .friend {
            leaderboardState = .friendPreview
        } else if leaderboardEntries.isEmpty {
            leaderboardState = .empty
        } else {
            leaderboardState = .ready
        }
    }

    /// 익명 공유 설정 실패를 사용자 액션으로 이어질 수 있는 문구로 변환합니다.
    private func visibilityFailureMessage(from error: Error) -> String {
        guard let supabaseError = error as? SupabaseHTTPError else {
            return "설정 반영 실패, 다시 시도해주세요."
        }
        switch supabaseError {
        case .notConfigured:
            return "Supabase 설정이 누락되어 있어요. 설정 파일을 확인해주세요."
        case .unexpectedStatusCode(let statusCode):
            switch statusCode {
            case 400, 401, 403:
                return "인증 세션 확인이 필요해요. 다시 로그인 후 시도해주세요."
            case 404:
                return "근처 공유 기능이 아직 서버에 배포되지 않았어요."
            case 500...599:
                return "서버 설정이 준비되지 않았어요. 잠시 후 다시 시도해주세요."
            default:
                return "설정 반영 실패(\(statusCode))"
            }
        case .invalidURL, .invalidBody, .invalidResponse:
            return "요청 형식 확인이 필요해요. 앱을 재시작 후 다시 시도해주세요."
        }
    }

    /// 핫스팟 요약 텍스트를 계산해 카드에 표시합니다.
    private func updateHotspotSummary() {
        guard let maximum = hotspots.map(\.intensity).max() else {
            maxIntensityText = "없음"
            lastUpdatedText = "-"
            hotspotPreviewRows = []
            return
        }
        if maximum >= 0.67 {
            maxIntensityText = "높음"
        } else if maximum >= 0.34 {
            maxIntensityText = "보통"
        } else {
            maxIntensityText = "낮음"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        lastUpdatedText = formatter.string(from: Date())
        hotspotPreviewRows = hotspots
            .sorted(by: { $0.intensity > $1.intensity })
            .prefix(3)
            .map { hotspot in
                HotspotPreviewRow(
                    title: "격자 \(hotspot.geohash.prefix(5))",
                    value: "\(Int(hotspot.intensity * 100))% · \(hotspot.count)명"
                )
            }
    }

    /// 주기 조회 타이머를 시작해 공유 중 상태에서 10초마다 핫스팟을 갱신합니다.
    private func startPollingIfNeeded() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshHotspots(force: false)
                self?.refreshLeaderboard(force: false)
            }
        }
    }

    /// 저장된 숨김/차단 익명 코드 목록을 불러옵니다.
    private func loadModerationPreferences() {
        hiddenAliases = Array(Set(preferenceStore.stringArray(forKey: hiddenAliasKey))).sorted()
        blockedAliases = Array(Set(preferenceStore.stringArray(forKey: blockedAliasKey))).sorted()
    }

    /// 현재 숨김/차단 익명 코드 목록을 로컬 설정에 저장합니다.
    private func persistModerationPreferences() {
        preferenceStore.set(hiddenAliases.sorted(), forKey: hiddenAliasKey)
        preferenceStore.set(blockedAliases.sorted(), forKey: blockedAliasKey)
    }

    /// 리더보드 원본 데이터에 숨김/차단 필터를 적용해 사용자 노출 목록을 갱신합니다.
    private func applyLeaderboardModerationFilter() {
        let blocked = Set(blockedAliases)
        let hidden = Set(hiddenAliases)
        leaderboardEntries = latestRawLeaderboardEntries.filter { row in
            blocked.contains(row.aliasCode) == false && hidden.contains(row.aliasCode) == false
        }
        if compareScope == .friend {
            leaderboardState = .friendPreview
        } else if leaderboardEntries.isEmpty {
            leaderboardState = .empty
        } else {
            leaderboardState = .ready
        }
    }

    /// 신고/차단/숨김 이력을 로컬 JSON 로그에 누적합니다.
    private func appendModerationLog(action: String, aliasCode: String, reason: String?) {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        var logs: [RivalModerationLogEntry] = []
        if let data = preferenceStore.data(forKey: moderationLogKey),
           let decoded = try? decoder.decode([RivalModerationLogEntry].self, from: data) {
            logs = decoded
        }
        let entry = RivalModerationLogEntry(
            action: action,
            aliasCode: aliasCode,
            reason: reason,
            createdAt: Date().timeIntervalSince1970
        )
        logs.append(entry)
        if logs.count > 200 {
            logs.removeFirst(logs.count - 200)
        }
        let encoded = try? encoder.encode(logs)
        preferenceStore.set(encoded, forKey: moderationLogKey)
    }

    /// 네트워크 계열 오류 여부를 판별합니다.
    private func isConnectivityError(_ error: Error) -> Bool {
        if error is URLError {
            return true
        }
        if let supabaseError = error as? SupabaseHTTPError {
            switch supabaseError {
            case .unexpectedStatusCode(let code):
                return code == 429 || (500...599).contains(code)
            default:
                return false
            }
        }
        return false
    }

    /// 위치 권한이 바뀌면 화면 상태를 즉시 재계산합니다.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updatePermissionState()
        refreshViewState()
        refreshHotspots(force: true)
        refreshLeaderboard(force: true)
    }

    /// 새 좌표를 받으면 공유 상태에서만 핫스팟을 즉시 갱신합니다.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard locations.isEmpty == false,
              locationSharingEnabled else { return }
        refreshHotspots(force: false)
        refreshLeaderboard(force: false)
    }
}

enum RivalCompareScope: String, CaseIterable {
    case rival
    case friend
}

enum RivalReportReason: String, CaseIterable {
    case inappropriate = "inappropriate"
    case spam = "spam"
    case suspectedCheat = "suspected_cheat"

    var title: String {
        switch self {
        case .inappropriate:
            return "부적절한 활동"
        case .spam:
            return "스팸/도배"
        case .suspectedCheat:
            return "기록 조작 의심"
        }
    }
}

private struct RivalModerationLogEntry: Codable {
    let action: String
    let aliasCode: String
    let reason: String?
    let createdAt: TimeInterval
}
