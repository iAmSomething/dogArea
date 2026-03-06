//
//  AuthFlowCoordinator.swift
//  dogArea
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AuthFlowCoordinator: ObservableObject {
    @Published var shouldShowEntryChoice: Bool = false
    @Published var shouldShowSignIn: Bool = false
    @Published var pendingUpgradeRequest: MemberUpgradeRequest? = nil
    @Published var pendingGuestDataUpgradePrompt: GuestDataUpgradePrompt? = nil
    @Published var guestDataUpgradeInProgress: Bool = false
    @Published var guestDataUpgradeResult: GuestDataUpgradeReport? = nil
    @Published private(set) var sessionStateSnapshot: AppSessionState = AppFeatureGate.currentSession()

    private let guestModeKey = "auth.guest_mode.v1"
    private let entryChoiceCompletedKey = "auth.entry_choice_completed.v1"
    private let guestDataUpgradeService = GuestDataUpgradeService.shared
    private let authSessionStore: AuthSessionStoreProtocol
    private let profileStore: ProfileStoring
    private let petSelectionStore: PetSelectionStoring
    private let walkSessionMetadataStore: WalkSessionMetadataStore
    private var onAuthenticated: (() -> Void)?
    private var authSessionObserver: AnyCancellable?
    private var shouldPresentDeferredSignIn: Bool = false

    /// 인증/프로필/선호 스토어 의존성을 주입해 인증 플로우 코디네이터를 초기화합니다.
    /// - Parameters:
    ///   - authSessionStore: 로그인 세션(토큰/사용자 식별자) 저장소입니다.
    ///   - profileStore: 로컬 프로필 스냅샷 저장소입니다.
    ///   - petSelectionStore: 반려견 선택 상태 저장소입니다.
    ///   - walkSessionMetadataStore: 산책 메타데이터/선호 설정 저장소입니다.
    init(
        authSessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared,
        profileStore: ProfileStoring = ProfileStore.shared,
        petSelectionStore: PetSelectionStoring = PetSelectionStore.shared,
        walkSessionMetadataStore: WalkSessionMetadataStore = .shared
    ) {
        self.authSessionStore = authSessionStore
        self.profileStore = profileStore
        self.petSelectionStore = petSelectionStore
        self.walkSessionMetadataStore = walkSessionMetadataStore
        bindAuthSessionSync()
    }

    deinit {
        authSessionObserver?.cancel()
    }

    var sessionState: AppSessionState {
        sessionStateSnapshot
    }

    var isLoggedIn: Bool {
        sessionState.isMember
    }

    var isGuestMode: Bool {
        isLoggedIn == false && UserDefaults.standard.bool(forKey: guestModeKey)
    }

    func refresh() {
        syncSessionStateSnapshot()
        if isLoggedIn {
            UserDefaults.standard.set(false, forKey: guestModeKey)
            UserDefaults.standard.set(true, forKey: entryChoiceCompletedKey)
            shouldPresentDeferredSignIn = false
            shouldShowEntryChoice = false
            shouldShowSignIn = false
            pendingUpgradeRequest = nil
            return
        }
        pendingGuestDataUpgradePrompt = nil
        guestDataUpgradeInProgress = false
        guestDataUpgradeResult = nil
        let didChooseEntryPath = UserDefaults.standard.bool(forKey: entryChoiceCompletedKey)
        shouldShowEntryChoice = !didChooseEntryPath
    }

    func continueAsGuest() {
        UserDefaults.standard.set(true, forKey: guestModeKey)
        UserDefaults.standard.set(true, forKey: entryChoiceCompletedKey)
        shouldShowEntryChoice = false
    }

    func chooseSignInFromEntry() {
        UserDefaults.standard.set(true, forKey: entryChoiceCompletedKey)
        shouldPresentDeferredSignIn = true
        shouldShowEntryChoice = false
    }

    func canAccess(_ feature: FeatureCapability) -> Bool {
        AppFeatureGate.isAllowed(feature, session: sessionState)
    }

    @discardableResult
    func requestAccess(feature: FeatureCapability, onAllowed: (() -> Void)? = nil) -> Bool {
        let decision = AppFeatureGate.decision(for: feature, session: sessionState)
        switch decision {
        case .allowed:
            onAllowed?()
            return true
        case .requiresMember(let trigger):
            return requireMember(trigger: trigger, onAuthenticated: onAllowed)
        }
    }

    @discardableResult
    func requireMember(trigger: MemberUpgradeTrigger, onAuthenticated: (() -> Void)? = nil) -> Bool {
        if isLoggedIn {
            onAuthenticated?()
            return true
        }
        self.onAuthenticated = onAuthenticated
        pendingUpgradeRequest = MemberUpgradeRequest(trigger: trigger)
        return false
    }

    func proceedToSignIn() {
        shouldPresentDeferredSignIn = true
        pendingUpgradeRequest = nil
    }

    func dismissUpgradeRequest() {
        shouldPresentDeferredSignIn = false
        pendingUpgradeRequest = nil
        onAuthenticated = nil
    }

    func dismissSignIn() {
        shouldPresentDeferredSignIn = false
        shouldShowSignIn = false
        if isLoggedIn == false {
            UserDefaults.standard.set(true, forKey: guestModeKey)
        }
        onAuthenticated = nil
    }

    func startReauthenticationFlow() {
        authSessionStore.clearTokenSession()
        syncSessionStateSnapshot()
        shouldPresentDeferredSignIn = false
        pendingUpgradeRequest = nil
        pendingGuestDataUpgradePrompt = nil
        shouldShowEntryChoice = false
        shouldShowSignIn = true
        onAuthenticated = nil
    }

    func dismissGuestDataUpgradePrompt() {
        pendingGuestDataUpgradePrompt = nil
    }

    func clearGuestDataUpgradeResult() {
        guestDataUpgradeResult = nil
    }

    /// 현재 로그인 세션과 로컬 프로필 상태를 모두 정리하고 게스트 진입 상태로 전환합니다.
    func signOut() {
        authSessionStore.clear()
        profileStore.removeAll()
        petSelectionStore.clearSelectionState()
        walkSessionMetadataStore.clearPreferences()
        UserDefaults.standard.set(false, forKey: guestModeKey)
        UserDefaults.standard.set(false, forKey: entryChoiceCompletedKey)
        pendingUpgradeRequest = nil
        pendingGuestDataUpgradePrompt = nil
        guestDataUpgradeInProgress = false
        guestDataUpgradeResult = nil
        onAuthenticated = nil
        refresh()
    }

    func startGuestDataUpgrade(forceRetry: Bool = false) {
        guard let userId = currentMemberUserId() else {
            #if DEBUG
            print("[AuthFlow] startGuestDataUpgrade aborted: missing member session/token")
            #endif
            return
        }
        #if DEBUG
        print("[AuthFlow] startGuestDataUpgrade user=\(userId) forceRetry=\(forceRetry)")
        #endif
        pendingGuestDataUpgradePrompt = nil
        guestDataUpgradeInProgress = true
        Task {
            let report = await guestDataUpgradeService.runUpgrade(for: userId, forceRetry: forceRetry)
            await MainActor.run {
                self.guestDataUpgradeInProgress = false
                self.guestDataUpgradeResult = report
                #if DEBUG
                if let report {
                    print(
                        "[AuthFlow] guest upgrade completed outstanding=\(report.hasOutstandingWork) pending=\(report.pendingCount) permanent=\(report.permanentFailureCount) lastError=\(report.lastErrorCode ?? "none")"
                    )
                } else {
                    print("[AuthFlow] guest upgrade completed with nil report")
                }
                #endif
            }
        }
    }

    func latestGuestDataUpgradeReport() -> GuestDataUpgradeReport? {
        guard let userId = currentMemberUserId() else {
            return nil
        }
        return guestDataUpgradeService.latestReport(for: userId)
    }

    func completeSignIn() {
        syncSessionStateSnapshot()
        UserDefaults.standard.set(false, forKey: guestModeKey)
        UserDefaults.standard.set(true, forKey: entryChoiceCompletedKey)
        shouldPresentDeferredSignIn = false
        shouldShowSignIn = false
        shouldShowEntryChoice = false
        pendingUpgradeRequest = nil
        if let userId = currentMemberUserId() {
            pendingGuestDataUpgradePrompt = guestDataUpgradeService.pendingPrompt(for: userId)
            guestDataUpgradeResult = guestDataUpgradeService.latestReport(for: userId)
        }
        let completion = onAuthenticated
        onAuthenticated = nil
        completion?()
    }

    /// 현재 인증 세션/프로필 스토어에서 사용자 식별자를 조회합니다.
    /// - Returns: 로그인 사용자 ID가 있으면 반환하고, 없으면 `nil`을 반환합니다.
    private func currentMemberUserId() -> String? {
        guard let sessionUserId = authSessionStore.currentIdentity()?.userId,
              sessionUserId.isEmpty == false else {
            return nil
        }
        guard authSessionStore.currentTokenSession() != nil else {
            return nil
        }
        return sessionUserId
    }

    /// 저장소 기준 최신 세션 상태를 계산해 `@Published` 스냅샷으로 반영합니다.
    /// - Returns: 없음. 세션 전환이 있으면 SwiftUI 갱신 트리거를 발생시킵니다.
    private func syncSessionStateSnapshot() {
        sessionStateSnapshot = AppFeatureGate.currentSession()
    }

    /// 인증 세션 변경 알림을 구독해 코디네이터 상태를 즉시 동기화합니다.
    private func bindAuthSessionSync() {
        authSessionObserver = NotificationCenter.default.publisher(for: .authSessionDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    /// 시트 해제 직후 예약된 로그인 화면 전환이 있으면 full screen 로그인 플로우를 시작합니다.
    /// - Returns: 없음. 예약된 전환 플래그가 있을 때만 `shouldShowSignIn`을 활성화합니다.
    func presentDeferredSignInIfNeeded() {
        guard shouldPresentDeferredSignIn else { return }
        shouldPresentDeferredSignIn = false
        shouldShowSignIn = true
    }
}

struct MemberUpgradeSheetView: View {
    let request: MemberUpgradeRequest
    let onUpgrade: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(request.trigger.title)
                .font(.appFont(for: .Bold, size: 22))
                .foregroundStyle(Color.appTextDarkGray)
            Text(request.trigger.message)
                .font(.appFont(for: .Regular, size: 14))
                .foregroundStyle(Color.appTextDarkGray)
            VStack(alignment: .leading, spacing: 8) {
                Text("• 계정 연동 후 자동 백업")
                Text("• 기기 변경 시 기록 복원")
                Text("• 로그인 완료 후 현재 화면으로 복귀")
            }
            .font(.appFont(for: .Regular, size: 13))
            .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 10) {
                Button("나중에") {
                    onLater()
                }
                .accessibilityIdentifier("sheet.memberUpgrade.later")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appYellowPale)
                .foregroundStyle(Color.appTextDarkGray)
                .cornerRadius(10)

                Button("로그인하고 계속") {
                    onUpgrade()
                }
                .accessibilityIdentifier("sheet.memberUpgrade.signin")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appGreen)
                .foregroundStyle(Color.white)
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color.white)
    }
}

struct GuestDataUpgradePromptSheetView: View {
    let prompt: GuestDataUpgradePrompt
    let onImport: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(prompt.shouldEmphasizeRetry ? "산책 데이터 이관 재시도" : "게스트 산책 데이터 가져오기")
                .font(.appFont(for: .Bold, size: 22))
                .foregroundStyle(Color.appTextDarkGray)
            Text("로그인 전에 기록한 산책 데이터를 계정으로 이관합니다. 중복 없이 안전하게 처리돼요.")
                .font(.appFont(for: .Regular, size: 14))
                .foregroundStyle(Color.appTextDarkGray)
            VStack(alignment: .leading, spacing: 6) {
                Text("세션 \(prompt.snapshot.sessionCount)건")
                Text("포인트 \(prompt.snapshot.pointCount)건")
                Text("누적 면적 \(prompt.snapshot.totalAreaM2.calculatedAreaString)")
                Text("누적 시간 \(prompt.snapshot.totalDurationSec.walkingTimeInterval)")
            }
            .font(.appFont(for: .Regular, size: 13))
            .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 10) {
                Button("나중에") {
                    onLater()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appYellowPale)
                .foregroundStyle(Color.appTextDarkGray)
                .cornerRadius(10)

                Button(prompt.shouldEmphasizeRetry ? "다시 가져오기" : "가져오기") {
                    onImport()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appGreen)
                .foregroundStyle(Color.white)
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color.white)
    }
}
