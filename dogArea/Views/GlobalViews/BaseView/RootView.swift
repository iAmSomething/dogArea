//
//  RootView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

struct RootView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var myAlert: CustomAlertViewModel
    @EnvironmentObject var authFlow: AuthFlowCoordinator
    @StateObject var loading: LoadingViewModel = LoadingViewModel()
    @State private var selectedTab = RootView.initialSelectedTabForRuntime()
    @State private var tabBarVisibility: AppTabBarVisibility = .automatic
    @State private var pendingWalkWidgetRoute: WalkWidgetActionRoute? = nil
    @State private var didDispatchUITestWidgetRoute = false
    @StateObject private var mapViewModelStore = MapViewModelStore()
    private let widgetActionStore: WalkWidgetActionRequestStoring = DefaultWalkWidgetActionRequestStore.shared
    private let territoryWidgetSnapshotSyncService: TerritoryWidgetSnapshotSyncing = DefaultTerritoryWidgetSnapshotSyncService()
    private let hotspotWidgetSnapshotSyncService: HotspotWidgetSnapshotSyncing = DefaultHotspotWidgetSnapshotSyncService()
    private let questRivalWidgetSnapshotSyncService: QuestRivalWidgetSnapshotSyncing = DefaultQuestRivalWidgetSnapshotSyncService()
    private let questRewardClaimService: QuestRewardClaimServiceProtocol = QuestRewardClaimService()
    private let questRivalSnapshotStore: QuestRivalWidgetSnapshotStoring = DefaultQuestRivalWidgetSnapshotStore.shared
    private var homeView = HomeView()
    private var walkListView = WalkListView()
    private var notificationCenterView = NotificationCenterView()
    private var isAuthenticationOverlayActive: Bool {
        authFlow.shouldShowSignIn || authFlow.shouldShowEntryChoice
    }

    /// UI 테스트 디자인 감사 모드에서는 기본 진입 탭을 홈으로 고정해 초기 렌더링 안정성을 높입니다.
    private static func initialSelectedTabForRuntime() -> Int {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-UITest.DesignAudit") {
            return 0
        }
        return 2
    }

    /// UI 테스트 런치 인자로 요청된 위젯 라우트를 파싱합니다.
    /// - Returns: 테스트 런타임에서 지정한 위젯 라우트가 있으면 반환하고, 없으면 `nil`을 반환합니다.
    private static func initialUITestWidgetRoute() -> WalkWidgetActionRoute? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-UITest.WidgetRoute"),
              arguments.indices.contains(index + 1),
              let kind = WalkWidgetActionKind(rawValue: arguments[index + 1]) else {
            return nil
        }
        return WalkWidgetActionRoute(
            kind: kind,
            actionId: "ui-test-widget-route",
            source: "ui-test",
            contextId: nil
        )
    }

    var body: some View {
        tabContent
            .appTabBarReservedHeight(AppTabLayoutMetrics.defaultTabBarReservedHeight)
            .onPreferenceChange(AppTabBarVisibilityPreferenceKey.self) { visibility in
                tabBarVisibility = visibility
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if tabBarVisibility != .hidden {
                    CustomTabBar(selectedTab: $selectedTab)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Color.appTabScaffoldBackground.ignoresSafeArea())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(content: {
                if loading.phase == .loading {
                    LoadingView()
                }
            })
            .overlay(alignment: .top) {
                if authFlow.guestDataUpgradeInProgress {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("게스트 데이터를 계정으로 이관 중...")
                            .font(.appFont(for: .Regular, size: 12))
                            .foregroundStyle(Color.appTextDarkGray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(10)
                    .padding(.top, 12)
                } else if let report = authFlow.guestDataUpgradeResult {
                    GuestDataUpgradeResultBanner(
                        report: report,
                        onRetry: { authFlow.startGuestDataUpgrade(forceRetry: true) },
                        onDismiss: { authFlow.clearGuestDataUpgradeResult() }
                    )
                    .padding(.top, 12)
                }
            }
            .sheet(item: $authFlow.pendingUpgradeRequest, onDismiss: {
                #if DEBUG
                print("[AuthFlow] RootView pendingUpgradeRequest onDismiss")
                #endif
                authFlow.presentDeferredSignInIfNeeded()
            }) { request in
                MemberUpgradeSheetView(
                    request: request,
                    onUpgrade: { authFlow.proceedToSignIn() },
                    onLater: { authFlow.dismissUpgradeRequest() }
                )
                .presentationDetents([.medium])
            }
            .sheet(item: $authFlow.pendingGuestDataUpgradePrompt) { prompt in
                GuestDataUpgradePromptSheetView(
                    prompt: prompt,
                    onImport: { authFlow.startGuestDataUpgrade(forceRetry: prompt.shouldEmphasizeRetry) },
                    onLater: { authFlow.dismissGuestDataUpgradePrompt() }
                )
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $authFlow.shouldShowSignIn) {
                SignInView(
                    allowDismiss: true,
                    onAuthenticated: { authFlow.completeSignIn() },
                    onDismiss: { authFlow.dismissSignIn() }
                )
            }
            .onAppear {
                dispatchUITestWidgetActionIfNeeded()
                consumePendingWidgetActionIfNeeded()
                syncTerritoryWidgetSnapshot(force: true)
                syncHotspotWidgetSnapshot(force: true)
                syncQuestRivalWidgetSnapshot(force: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                consumePendingWidgetActionIfNeeded()
                syncTerritoryWidgetSnapshot(force: false)
                syncHotspotWidgetSnapshot(force: false)
                syncQuestRivalWidgetSnapshot(force: false)
            }
            .onReceive(NotificationCenter.default.publisher(for: UserdefaultSetting.selectedPetDidChangeNotification)) { _ in
                syncTerritoryWidgetSnapshot(force: true)
                syncHotspotWidgetSnapshot(force: true)
                syncQuestRivalWidgetSnapshot(force: true)
            }
            .onOpenURL { url in
                routeWidgetDeepLinkIfNeeded(url)
            }
            .onChange(of: isAuthenticationOverlayActive) { _, isPresented in
                if isPresented {
                    mapViewModelStore.suspendForAuthenticationOverlay()
                    return
                }
                if selectedTab == 2 {
                    mapViewModelStore.prepareIfNeeded()
                }
                dispatchPendingWalkWidgetActionIfNeeded()
            }

    }

    @ViewBuilder
    private var tabContent: some View {
        if selectedTab == 0 {
            AppTabRootContainer(accessibilityIdentifier: "screen.home") {
                homeView
            }
        } else if selectedTab == 1 {
            AppTabRootContainer(
                accessibilityIdentifier: "screen.walkList",
                hidesNavigationBar: false
            ) {
                walkListView
            }
        } else if selectedTab == 2 {
            AppTabRootContainer(
                accessibilityIdentifier: isAuthenticationOverlayActive
                    ? "screen.map.suspended"
                    : "screen.map"
            ) {
                Group {
                    if isAuthenticationOverlayActive {
                        Color.appTabScaffoldBackground
                            .ignoresSafeArea()
                            .accessibilityIdentifier("screen.map.suspended")
                    } else {
                        if let mapViewModel = mapViewModelStore.mapViewModel {
                            MapView(viewModel: mapViewModel)
                                .environmentObject(loading)
                        } else {
                            ProgressView("지도 준비 중...")
                                .font(.appFont(for: .Regular, size: 14))
                                .foregroundStyle(Color.appTextDarkGray)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .onAppear {
                                    mapViewModelStore.prepareIfNeeded()
                                }
                        }
                    }
                }
            }
        } else if selectedTab == 3 {
            AppTabRootContainer(accessibilityIdentifier: "screen.rival") {
                RivalTabView(
                    onOpenMap: { selectedTab = 2 },
                    onOpenSettings: { selectedTab = 4 }
                )
            }
        } else if selectedTab == 4 {
            AppTabRootContainer(accessibilityIdentifier: "screen.settings") {
                notificationCenterView
            }
        }
    }

    /// 위젯에서 전달된 딥링크를 파싱해 지도 탭 액션으로 전달합니다.
    /// - Parameter url: 앱으로 유입된 URL 스킴 딥링크입니다.
    private func routeWidgetDeepLinkIfNeeded(_ url: URL) {
        #if DEBUG
        print("[WidgetAction] onOpenURL received: \(url.absoluteString)")
        #endif
        guard let route = WalkWidgetActionRoute.parse(from: url) else { return }
        #if DEBUG
        print("[WidgetAction] parsed deep link kind=\(route.kind.rawValue) actionId=\(route.actionId) source=\(route.source)")
        #endif
        dispatchWidgetAction(route)
    }

    /// 공유 저장소에 대기 중인 위젯 액션 요청을 소비해 앱 내부 액션으로 전달합니다.
    private func consumePendingWidgetActionIfNeeded() {
        guard let request = widgetActionStore.consumePending() else { return }
        #if DEBUG
        print("[WidgetAction] consumed pending request kind=\(request.kind.rawValue) actionId=\(request.actionId) source=\(request.source)")
        #endif
        dispatchWidgetAction(request.asRoute())
    }

    /// UI 테스트 런타임에서 지정한 위젯 라우트를 한 번만 앱 내부 액션으로 전달합니다.
    private func dispatchUITestWidgetActionIfNeeded() {
        guard didDispatchUITestWidgetRoute == false,
              let route = Self.initialUITestWidgetRoute() else { return }
        didDispatchUITestWidgetRoute = true
        dispatchWidgetAction(route)
    }

    /// 위젯 액션 라우트를 종류에 맞는 탭/서비스로 전달합니다.
    /// - Parameter route: 앱 내부에서 처리할 위젯 액션 라우트입니다.
    private func dispatchWidgetAction(_ route: WalkWidgetActionRoute) {
        #if DEBUG
        print("[WidgetAction] dispatch kind=\(route.kind.rawValue) actionId=\(route.actionId) source=\(route.source)")
        #endif
        switch route.kind {
        case .startWalk, .endWalk:
            dispatchWalkWidgetAction(route)
        case .openRivalTab:
            selectedTab = 3
        case .claimQuestReward:
            selectedTab = 0
            handleQuestRewardClaimFromWidget(route)
        }
    }

    /// 산책 관련 위젯 액션을 지도 탭으로 전달합니다.
    /// - Parameter route: 지도 화면에서 처리할 위젯 액션 라우트입니다.
    private func dispatchWalkWidgetAction(_ route: WalkWidgetActionRoute) {
        if isAuthenticationOverlayActive {
            pendingWalkWidgetRoute = route
            selectedTab = 2
            #if DEBUG
            print("[WidgetAction] deferred walk action during auth overlay actionId=\(route.actionId)")
            #endif
            return
        }
        pendingWalkWidgetRoute = nil
        mapViewModelStore.prepareIfNeeded()
        selectedTab = 2
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            #if DEBUG
            print("[WidgetAction] posting walkWidgetActionRequested kind=\(route.kind.rawValue) actionId=\(route.actionId)")
            #endif
            NotificationCenter.default.post(
                name: .walkWidgetActionRequested,
                object: nil,
                userInfo: [
                    "kind": route.kind.rawValue,
                    "actionId": route.actionId,
                    "source": route.source,
                    "contextId": route.contextId as Any
                ]
            )
        }
    }

    /// 인증 오버레이 해제 후 대기 중인 위젯 산책 액션이 있으면 즉시 재처리합니다.
    private func dispatchPendingWalkWidgetActionIfNeeded() {
        guard let pendingWalkWidgetRoute else { return }
        dispatchWalkWidgetAction(pendingWalkWidgetRoute)
    }

    /// 위젯 보상 수령 액션을 멱등 요청으로 처리하고 스냅샷 상태를 갱신합니다.
    /// - Parameter route: 보상 수령 대상 퀘스트 식별자를 포함한 액션 라우트입니다.
    private func handleQuestRewardClaimFromWidget(_ route: WalkWidgetActionRoute) {
        let snapshot = questRivalSnapshotStore.load()
        let targetQuestId = route.contextId ?? snapshot.summary?.questInstanceId
        guard let questInstanceId = targetQuestId?.canonicalUUIDString else {
            syncQuestRivalWidgetSnapshot(force: true)
            return
        }

        let inFlight = QuestRivalWidgetSnapshot(
            status: .claimInFlight,
            message: "보상 수령 요청을 처리 중입니다.",
            summary: snapshot.summary,
            contextKey: snapshot.contextKey,
            updatedAt: Date().timeIntervalSince1970
        )
        saveQuestRivalWidgetSnapshot(inFlight)

        Task(priority: .userInitiated) {
            do {
                let claim = try await questRewardClaimService.claimReward(
                    questInstanceId: questInstanceId,
                    requestId: route.actionId,
                    now: Date()
                )
                let latest = questRivalSnapshotStore.load()
                let updatedSummary = latest.summary.map { summary in
                    QuestRivalWidgetSummarySnapshot(
                        questInstanceId: summary.questInstanceId,
                        questTitle: summary.questTitle,
                        questProgressValue: summary.questProgressValue,
                        questTargetValue: summary.questTargetValue,
                        questProgressRatio: summary.questProgressRatio,
                        questClaimable: false,
                        questRewardPoint: claim.rewardPoints,
                        rivalRank: summary.rivalRank,
                        rivalRankDelta: summary.rivalRankDelta,
                        rivalLeague: summary.rivalLeague,
                        refreshedAt: Date().timeIntervalSince1970
                    )
                }
                let successSnapshot = QuestRivalWidgetSnapshot(
                    status: .claimSucceeded,
                    message: claim.alreadyClaimed
                        ? "이미 수령 처리된 보상입니다."
                        : "보상 \(claim.rewardPoints)pt 수령 완료!",
                    summary: updatedSummary,
                    contextKey: latest.contextKey,
                    updatedAt: Date().timeIntervalSince1970
                )
                saveQuestRivalWidgetSnapshot(successSnapshot)
            } catch {
                let latest = questRivalSnapshotStore.load()
                let failedSnapshot = QuestRivalWidgetSnapshot(
                    status: .claimFailed,
                    message: "보상 수령에 실패했어요. 앱에서 다시 시도해주세요.",
                    summary: latest.summary,
                    contextKey: latest.contextKey,
                    updatedAt: Date().timeIntervalSince1970
                )
                saveQuestRivalWidgetSnapshot(failedSnapshot)
            }
            await questRivalWidgetSnapshotSyncService.sync(force: true, now: Date())
        }
    }

    /// 퀘스트/라이벌 스냅샷을 저장하고 WidgetKit 타임라인을 즉시 재요청합니다.
    /// - Parameter snapshot: 저장할 퀘스트/라이벌 위젯 스냅샷입니다.
    private func saveQuestRivalWidgetSnapshot(_ snapshot: QuestRivalWidgetSnapshot) {
        questRivalSnapshotStore.save(snapshot)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: WalkWidgetBridgeContract.questRivalWidgetKind)
        #endif
    }

    /// 앱 생명주기 진입 시 영역 위젯 스냅샷 동기화를 요청합니다.
    /// - Parameter force: `true`면 TTL을 무시하고 즉시 동기화합니다.
    private func syncTerritoryWidgetSnapshot(force: Bool) {
        Task(priority: .utility) {
            await territoryWidgetSnapshotSyncService.sync(force: force, now: Date())
        }
    }

    /// 앱 생명주기 진입 시 익명 핫스팟 위젯 스냅샷 동기화를 요청합니다.
    /// - Parameter force: `true`면 TTL을 무시하고 즉시 동기화합니다.
    private func syncHotspotWidgetSnapshot(force: Bool) {
        Task(priority: .utility) {
            await hotspotWidgetSnapshotSyncService.sync(force: force, now: Date())
        }
    }

    /// 앱 생명주기 진입 시 퀘스트/라이벌 위젯 스냅샷 동기화를 요청합니다.
    /// - Parameter force: `true`면 TTL을 무시하고 즉시 동기화합니다.
    private func syncQuestRivalWidgetSnapshot(force: Bool) {
        Task(priority: .utility) {
            await questRivalWidgetSnapshotSyncService.sync(force: force, now: Date())
        }
    }
}

@MainActor
private final class MapViewModelStore: ObservableObject {
    @Published private(set) var mapViewModel: MapViewModel?

    /// 지도 탭 진입이나 위젯 액션 처리 직전에 지도 ViewModel을 지연 생성합니다.
    /// - Important: 이미 생성된 인스턴스가 있으면 재생성하지 않아 탭 전환 중 상태를 유지합니다.
    func prepareIfNeeded() {
        guard mapViewModel == nil else { return }
        mapViewModel = MapViewModel()
    }

    /// 인증 오버레이가 보이는 동안 Metal 렌더 경합을 막기 위해 지도 ViewModel을 해제합니다.
    func suspendForAuthenticationOverlay() {
        mapViewModel = nil
    }
}

private struct GuestDataUpgradeResultBanner: View {
    let report: GuestDataUpgradeReport
    let onRetry: () -> Void
    let onDismiss: () -> Void

    private var validationText: String? {
        guard let passed = report.validationPassed else { return nil }
        return passed ? "원격 검증 통과" : "원격 검증 실패: \(report.validationMessage ?? "mismatch")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(report.hasOutstandingWork ? "데이터 이관 진행 중" : "데이터 이관 완료")
                .font(.appFont(for: .SemiBold, size: 13))
            Text(
                "세션 \(report.sessionCount)건 · 포인트 \(report.pointCount)건 · \(report.totalAreaM2.calculatedAreaString)"
            )
            .font(.appFont(for: .Light, size: 11))
            .foregroundStyle(Color.appTextDarkGray)
            if let validationText {
                Text(validationText)
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(report.validationPassed == true ? Color.appGreen : Color.appRed)
            }
            HStack(spacing: 10) {
                if report.hasOutstandingWork {
                    Button("재시도") {
                        onRetry()
                    }
                    .font(.appFont(for: .SemiBold, size: 11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appYellow)
                    .cornerRadius(8)
                }
                Button("닫기") {
                    onDismiss()
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.95))
        .cornerRadius(12)
        .padding(.horizontal, 12)
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()
