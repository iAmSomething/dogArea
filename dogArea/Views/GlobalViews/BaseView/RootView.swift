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
    @State private var tabbarHidden = false
    @StateObject var tabStatus = TabAppear.shared
    private let widgetActionStore: WalkWidgetActionRequestStoring = DefaultWalkWidgetActionRequestStore.shared
    private let territoryWidgetSnapshotSyncService: TerritoryWidgetSnapshotSyncing = DefaultTerritoryWidgetSnapshotSyncService()
    private let hotspotWidgetSnapshotSyncService: HotspotWidgetSnapshotSyncing = DefaultHotspotWidgetSnapshotSyncService()
    private let questRivalWidgetSnapshotSyncService: QuestRivalWidgetSnapshotSyncing = DefaultQuestRivalWidgetSnapshotSyncService()
    private let questRewardClaimService: QuestRewardClaimServiceProtocol = QuestRewardClaimService()
    private let questRivalSnapshotStore: QuestRivalWidgetSnapshotStoring = DefaultQuestRivalWidgetSnapshotStore.shared
    private var homeView: HomeView
    private var walkListView: WalkListView    
    private var mapView: MapView
    private var notificationCenterView: NotificationCenterView
    init() {
        self.homeView = HomeView()
        self.walkListView = WalkListView()
        self.mapView = MapView()
        self.notificationCenterView = NotificationCenterView()
    }

    /// UI 테스트 디자인 감사 모드에서는 기본 진입 탭을 홈으로 고정해 초기 렌더링 안정성을 높입니다.
    private static func initialSelectedTabForRuntime() -> Int {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-UITest.DesignAudit") {
            return 0
        }
        return 2
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
            if tabStatus.isTabAppear {
                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 2)
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
            .sheet(item: $authFlow.pendingUpgradeRequest) { request in
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
            .onAppear {
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

    }

    @ViewBuilder
    private var tabContent: some View {
        if selectedTab == 0 {
            NavigationView {
                homeView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationBarHidden(selectedTab == 0)
                    .accessibilityIdentifier("screen.home")
            }
        } else if selectedTab == 1 {
            NavigationView {
                walkListView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationBarHidden(selectedTab == 1)
                    .accessibilityIdentifier("screen.walkList")
            }
        } else if selectedTab == 2 {
            NavigationView {
                mapView
                    .environmentObject(loading)
                    .navigationBarHidden(selectedTab == 2)
                    .accessibilityIdentifier("screen.map")
            }
        } else if selectedTab == 3 {
            NavigationView {
                RivalTabView(
                    onOpenMap: { selectedTab = 2 },
                    onOpenSettings: { selectedTab = 4 }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationBarHidden(selectedTab == 3)
                .accessibilityIdentifier("screen.rival")
            }
        } else if selectedTab == 4 {
            NavigationView {
                notificationCenterView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationBarHidden(selectedTab == 4)
                    .accessibilityIdentifier("screen.settings")
            }
        }
    }

    /// 위젯에서 전달된 딥링크를 파싱해 지도 탭 액션으로 전달합니다.
    /// - Parameter url: 앱으로 유입된 URL 스킴 딥링크입니다.
    private func routeWidgetDeepLinkIfNeeded(_ url: URL) {
        guard let route = WalkWidgetActionRoute.parse(from: url) else { return }
        dispatchWidgetAction(route)
    }

    /// 공유 저장소에 대기 중인 위젯 액션 요청을 소비해 앱 내부 액션으로 전달합니다.
    private func consumePendingWidgetActionIfNeeded() {
        guard let request = widgetActionStore.consumePending() else { return }
        dispatchWidgetAction(request.asRoute())
    }

    /// 위젯 액션 라우트를 종류에 맞는 탭/서비스로 전달합니다.
    /// - Parameter route: 앱 내부에서 처리할 위젯 액션 라우트입니다.
    private func dispatchWidgetAction(_ route: WalkWidgetActionRoute) {
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
        selectedTab = 2
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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
