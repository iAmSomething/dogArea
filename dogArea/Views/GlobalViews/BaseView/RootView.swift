//
//  RootView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import Foundation
import SwiftUI

struct RootView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var myAlert: CustomAlertViewModel
    @EnvironmentObject var authFlow: AuthFlowCoordinator
    @StateObject var loading: LoadingViewModel = LoadingViewModel()
    @State private var selectedTab = RootView.initialSelectedTabForRuntime()
    @State private var tabbarHidden = false
    @StateObject var tabStatus = TabAppear.shared
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
        VStack(spacing: 0) {
            if self.selectedTab == 0 {
                NavigationView {
                    homeView.frame(maxWidth: .infinity,maxHeight: .infinity)
                        .navigationBarHidden(selectedTab == 0)
                        .accessibilityIdentifier("screen.home")
                }
            }
            else if self.selectedTab == 1 {
                NavigationView {
                    walkListView.frame(maxWidth: .infinity,maxHeight: .infinity)
                        .navigationBarHidden(selectedTab == 1)
                        .accessibilityIdentifier("screen.walkList")
                }
            }
            else if self.selectedTab == 2 {
                NavigationView {
                    mapView
                        .environmentObject(loading)
                        .navigationBarHidden(selectedTab == 2)
                        .accessibilityIdentifier("screen.map")
                }
            }
            else if self.selectedTab == 3 {
                NavigationView {
                    RivalTabView(
                        onOpenMap: { selectedTab = 2 },
                        onOpenSettings: { selectedTab = 4 }
                    )
                        .frame(maxWidth: .infinity,maxHeight: .infinity)
                        .navigationBarHidden(selectedTab == 3)
                        .accessibilityIdentifier("screen.rival")
                }
            }
            else if self.selectedTab == 4 {
                NavigationView {
                    notificationCenterView.frame(maxWidth: .infinity,maxHeight: .infinity)
                        .navigationBarHidden(selectedTab == 4)
                        .accessibilityIdentifier("screen.settings")
                }
            }
            if tabStatus.isTabAppear {
                CustomTabBar(selectedTab: $selectedTab)
                    .frame(maxHeight: .infinity)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .edgesIgnoringSafeArea(.all)
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
