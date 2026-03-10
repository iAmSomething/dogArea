//
//  ContentsViewModel.swift
//  dogAreaWatch Watch App
//
//  Created by 김태훈 on 12/27/23.
//

import Foundation
import WatchConnectivity

struct WatchActionDTO: Codable, Equatable {
    let version: String
    let type: String
    let action: String
    let actionId: String
    let sentAt: TimeInterval
    let contextId: String?

    var envelope: [String: Any] {
        var payload: [String: Any] = [
            "action": action,
            "action_id": actionId,
            "sent_at": sentAt
        ]
        if let contextId, contextId.isEmpty == false {
            payload["context_id"] = contextId
        }
        var envelope: [String: Any] = [
            "version": version,
            "type": type,
            "action": action,
            "action_id": actionId,
            "sent_at": sentAt,
            "payload": payload
        ]
        if let contextId, contextId.isEmpty == false {
            envelope["context_id"] = contextId
        }
        return envelope
    }
}

enum WatchActionType: String {
    case startWalk = "startWalk"
    case addPoint = "addPoint"
    case endWalk = "endWalk"
    case discardWalk = "discardWalk"
    case syncState = "syncState"
}

enum WatchWalkEndDecision {
    case saveAndEnd
    case continueWalking
    case discardRecord
}

private struct WatchAckSnapshot: Codable, Equatable {
    let status: String
    let actionId: String
    let ackAt: TimeInterval?
}

final class ContentsViewModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isWalking = false
    @Published var walkingTime: TimeInterval = 0
    @Published var walkingArea: Double = 0
    @Published var currentWalkPointCount: Int = 0
    @Published var isReachable = false
    @Published var lastSyncAt: TimeInterval = 0
    @Published var pendingActionCount: Int = 0
    @Published var lastAckStatus: String = "대기"
    @Published var lastAckActionId: String = ""
    @Published private(set) var lastAckAt: TimeInterval?
    @Published var contractVersion: String = "watch.remote.v1"
    @Published private(set) var feedbackBanner: WatchActionFeedbackBanner?
    @Published private(set) var petContext: WatchSelectedPetContextState = .legacyFallback(
        isWalking: false,
        lastSyncAt: nil
    )
    @Published private(set) var queueStatus: WatchOfflineQueueStatusState = .empty(isReachable: false)
    @Published private(set) var walkCompletionSummary: WatchWalkCompletionSummaryState?

    private let actionQueueStorageKey = "watch.pendingActions.v1"
    private let ackSnapshotStorageKey = "watch.lastAckSnapshot.v1"
    private let presentedCompletionSummaryActionIdStorageKey = "watch.presentedCompletionSummaryActionId.v1"
    private let watchContractVersion = "watch.remote.v1"
    private let watchActionMessageType = "watch_action"
    private let watchAckMessageType = "watch_ack"
    private var pendingActions: [WatchActionDTO] = []
    private let session = WCSession.default
    private let hapticService: WatchActionHapticServicing
    private let syncRecoveryService: WatchSyncRecoveryPresenting
    private let manualSyncCooldownInterval: TimeInterval = 15
    private let manualSyncResponseGraceInterval: TimeInterval = 8
    @Published private var executionStates: [WatchActionType: WatchActionExecutionState] = [:]
    private var cooldownDeadlines: [WatchActionType: Date] = [:]
    private var actionTypeByActionId: [String: WatchActionType] = [:]
    private var resetWorkItems: [WatchActionType: DispatchWorkItem] = [:]
    private var lastCompletedActionId: String = ""
    private var lastPresentedCompletionSummaryActionId: String = ""
    private var manualSyncRecoveryPhase: WatchManualSyncRecoveryPhase = .idle
    private var nextManualSyncAllowedAt: TimeInterval?
    private var manualSyncResponseWorkItem: DispatchWorkItem?
    private var manualSyncCooldownRefreshWorkItem: DispatchWorkItem?
    private var lastAddPointTapHapticAt: TimeInterval = 0

    init(
        hapticService: WatchActionHapticServicing = DefaultWatchActionHapticService(),
        syncRecoveryService: WatchSyncRecoveryPresenting = DefaultWatchSyncRecoveryPresentationService()
    ) {
        self.hapticService = hapticService
        self.syncRecoveryService = syncRecoveryService
        super.init()
        loadPendingActions()
        loadAckSnapshot()
        loadPresentedCompletionSummaryActionId()
        refreshQueueStatus()
        activateSession()
    }

    var currentPointCount: Int {
        currentWalkPointCount
    }

    var currentWalkingPetName: String {
        petContext.petName
    }

    /// 워치 액션 버튼이 현재 렌더링해야 할 프레젠테이션 상태를 계산합니다.
    /// - Parameter action: 조회할 워치 액션 종류입니다.
    /// - Returns: 버튼 타이틀, 설명, 톤, 비활성 여부를 포함한 렌더링 상태입니다.
    func controlPresentation(for action: WatchActionType) -> WatchActionControlPresentation {
        let state = executionStates[action] ?? .idle
        if action == .startWalk, petContext.blocksInlineStart {
            return WatchActionControlPresentation(
                title: "앱에서 반려견 확인",
                detail: petContext.startBlockedDetail,
                tone: .warning,
                isDisabled: true,
                showsProgress: false
            )
        }
        switch state {
        case .idle:
            return WatchActionControlPresentation(
                title: action.baseTitle,
                detail: action.idleDetail,
                tone: .neutral,
                isDisabled: false,
                showsProgress: false
            )
        case .processing:
            return WatchActionControlPresentation(
                title: action.processingTitle,
                detail: "아이폰 응답을 기다리는 중이에요",
                tone: .processing,
                isDisabled: true,
                showsProgress: true
            )
        case .queued:
            return WatchActionControlPresentation(
                title: action.queuedTitle,
                detail: "연결되면 자동으로 다시 보냅니다",
                tone: .warning,
                isDisabled: action.blocksWhileQueued,
                showsProgress: false
            )
        case .acknowledged:
            return WatchActionControlPresentation(
                title: action.baseTitle,
                detail: "아이폰으로 전달됐어요",
                tone: .success,
                isDisabled: false,
                showsProgress: false
            )
        case .completed:
            return WatchActionControlPresentation(
                title: action.baseTitle,
                detail: "상태 반영을 확인했어요",
                tone: .success,
                isDisabled: false,
                showsProgress: false
            )
        case .duplicateSuppressed:
            return WatchActionControlPresentation(
                title: action.duplicateSuppressedTitle,
                detail: "방금 같은 요청을 처리했어요",
                tone: .warning,
                isDisabled: false,
                showsProgress: false
            )
        case .failed:
            return WatchActionControlPresentation(
                title: action.baseTitle,
                detail: "다시 한 번 시도해 주세요",
                tone: .failure,
                isDisabled: false,
                showsProgress: false
            )
        case .confirmRequired:
            return WatchActionControlPresentation(
                title: action.confirmationTitle,
                detail: "3초 안에 다시 탭하면 종료를 보냅니다",
                tone: .warning,
                isDisabled: false,
                showsProgress: false
            )
        }
    }

    /// 사용자가 watch 화면에서 액션 버튼을 탭했을 때 확인 단계와 중복 억제를 포함해 처리합니다.
    /// - Parameter action: 사용자가 요청한 워치 액션 종류입니다.
    func handleActionTap(_ action: WatchActionType) {
        guard action != .syncState else {
            sendAction(.syncState)
            return
        }
        if action == .startWalk, petContext.blocksInlineStart {
            presentBanner(
                title: "반려견 확인 필요",
                detail: petContext.startBlockedDetail,
                tone: .warning
            )
            sendAction(.syncState)
            return
        }
        if action == .endWalk, executionStates[action] == .confirmRequired {
            sendAction(action)
            return
        }
        if shouldSuppressDuplicateTap(for: action) {
            transition(action, to: .duplicateSuppressed, resetAfter: 1.2)
            presentBanner(
                title: "중복 입력 억제",
                detail: "같은 요청을 처리 중이라 잠시만 기다려 주세요.",
                tone: .warning,
                actionEvent: action == .addPoint ? .addPointDuplicateSuppressed : nil
            )
            return
        }
        if action == .endWalk {
            transition(action, to: .confirmRequired, resetAfter: action.confirmationWindow)
            presentBanner(
                title: "산책 종료 확인",
                detail: "오조작 방지를 위해 3초 안에 한 번 더 눌러 주세요.",
                tone: .warning
            )
            return
        }
        playInputAcknowledgementIfNeeded(for: action)
        sendAction(action)
    }

    /// 종료 결정 sheet에서 선택한 액션을 watch transport 경로로 전달하거나 로컬 상태만 정리합니다.
    /// - Parameter decision: 사용자가 종료 시트에서 선택한 의사결정입니다.
    func handleWalkEndDecision(_ decision: WatchWalkEndDecision) {
        switch decision {
        case .saveAndEnd:
            sendAction(.endWalk)
        case .continueWalking:
            presentBanner(
                title: "산책 계속",
                detail: "지금 산책을 그대로 이어서 기록합니다.",
                tone: .neutral,
                playsHaptic: false
            )
        case .discardRecord:
            sendAction(.discardWalk)
        }
    }

    /// 완료 요약 sheet를 닫고 현재 표시 중인 요약 상태를 초기화합니다.
    func dismissWalkCompletionSummary() {
        walkCompletionSummary = nil
    }

    /// 사용자가 큐 상태 화면에서 수동 재동기화를 요청했을 때 reachability에 맞춰 처리합니다.
    /// 오프라인이면 새 sync action을 큐에 쌓지 않고, 온라인일 때만 queue flush와 상태 재확인을 수행합니다.
    func handleManualQueueResync() {
        let now = Date().timeIntervalSince1970
        guard session.activationState == .activated, session.isReachable else {
            presentBanner(
                title: "연결 대기 중",
                detail: "지금은 오프라인이라 자동 재전송을 기다립니다. iPhone이 다시 연결되면 다시 동기화할 수 있어요.",
                tone: .warning
            )
            refreshQueueStatus()
            return
        }

        if let nextManualSyncAllowedAt, nextManualSyncAllowedAt > now {
            presentBanner(
                title: "잠시 후 다시",
                detail: queueStatus.syncRecovery.cooldownRemainingText ?? "연속 재시도를 막기 위해 잠시 대기해 주세요.",
                tone: .warning,
                playsHaptic: false
            )
            refreshQueueStatus()
            return
        }

        manualSyncRecoveryPhase = .processing(requestedAt: now)
        nextManualSyncAllowedAt = now + manualSyncCooldownInterval
        scheduleManualSyncResponseTimeout(requestedAt: now)
        scheduleManualSyncCooldownRefresh(deadline: now + manualSyncCooldownInterval)

        presentBanner(
            title: pendingActions.isEmpty ? "상태 다시 확인" : "큐 다시 동기화",
            detail: pendingActions.isEmpty
                ? "최신 ACK와 상태를 다시 확인합니다."
                : "대기 중인 요청과 최신 ACK 상태를 다시 확인합니다.",
            tone: .processing,
            playsHaptic: false
        )
        refreshQueueStatus()
        flushPendingActions()
        sendAction(.syncState)
    }

    /// WatchConnectivity 세션을 활성화하고 delegate를 연결합니다.
    /// 세션 활성화가 성공하면 이후 액션과 상태 동기화 요청을 받을 수 있습니다.
    private func activateSession() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    /// 워치 액션을 실제 transport 경로에 태워 전송하거나 큐에 적재합니다.
    /// - Parameter action: 전달할 워치 액션 종류입니다.
    func sendAction(_ action: WatchActionType) {
        if action == .syncState,
           (session.activationState != .activated || session.isReachable == false) {
            presentBanner(
                title: "오프라인 상태",
                detail: "상태 다시 확인은 연결이 돌아오면 다시 시도할 수 있어요. 새 동기화 요청은 큐에 추가하지 않았습니다.",
                tone: .warning
            )
            refreshQueueStatus()
            return
        }

        let dto = WatchActionDTO(
            version: watchContractVersion,
            type: watchActionMessageType,
            action: action.rawValue,
            actionId: UUID().uuidString.lowercased(),
            sentAt: Date().timeIntervalSince1970,
            contextId: action == .startWalk ? petContext.petId : nil
        )
        actionTypeByActionId[dto.actionId] = action
        cooldownDeadlines[action] = Date().addingTimeInterval(action.cooldownInterval)

        if action != .syncState {
            transition(action, to: .processing)
            presentBanner(
                title: action.processingTitle,
                detail: "아이폰으로 요청을 보내는 중입니다.",
                tone: .processing,
                playsHaptic: false
            )
        }

        if session.activationState == .activated, session.isReachable {
            sendImmediately(dto)
            return
        }

        enqueue(dto)
        if action != .syncState {
            transition(action, to: .queued, resetAfter: action == .addPoint ? 1.6 : nil)
            presentBanner(
                title: action.queuedTitle,
                detail: "현재 오프라인이라 큐에 저장했고, 연결되면 자동 전송합니다.",
                tone: .warning,
                actionEvent: action == .addPoint ? .addPointQueued : nil
            )
        }
        flushPendingActions()
    }

    /// 도달 가능한 세션에 액션을 즉시 전송하고 ACK 또는 큐 적재 결과를 반영합니다.
    /// - Parameter action: 즉시 전송할 워치 액션 DTO입니다.
    private func sendImmediately(_ action: WatchActionDTO) {
        let fallbackType = WatchActionType(rawValue: action.action)
        session.sendMessage(action.envelope, replyHandler: { [weak self] reply in
            self?.handleAck(reply, fallbackActionId: action.actionId, fallbackActionType: fallbackType)
        }, errorHandler: { [weak self] _ in
            self?.enqueue(action)
            self?.flushPendingActions()
            DispatchQueue.main.async {
                if let fallbackType {
                    self?.transition(fallbackType, to: .queued, resetAfter: fallbackType == .addPoint ? 1.6 : nil)
                    self?.presentBanner(
                        title: fallbackType.queuedTitle,
                        detail: "즉시 전송에는 실패했지만 큐에는 안전하게 보관했습니다.",
                        tone: .warning,
                        actionEvent: fallbackType == .addPoint ? .addPointQueued : nil
                    )
                }
            }
        })
    }

    /// pending queue에 동일 action id가 없다면 새 액션을 적재합니다.
    /// - Parameter action: 적재할 워치 액션 DTO입니다.
    private func enqueue(_ action: WatchActionDTO) {
        guard pendingActions.contains(where: { $0.actionId == action.actionId }) == false else { return }
        pendingActions.append(action)
        persistPendingActions()
        pendingActionCount = pendingActions.count
        refreshQueueStatus()
    }

    /// UserDefaults에 저장된 pending queue를 로드합니다.
    /// 저장 데이터가 없거나 복원에 실패하면 빈 queue 상태로 초기화합니다.
    private func loadPendingActions() {
        guard let data = UserDefaults.standard.data(forKey: actionQueueStorageKey),
              let decoded = try? JSONDecoder().decode([WatchActionDTO].self, from: data) else {
            pendingActions = []
            pendingActionCount = 0
            actionTypeByActionId = [:]
            refreshQueueStatus()
            return
        }
        pendingActions = decoded
        pendingActionCount = decoded.count
        actionTypeByActionId = Dictionary(
            uniqueKeysWithValues: decoded.compactMap { action in
                guard let type = WatchActionType(rawValue: action.action) else { return nil }
                return (action.actionId, type)
            }
        )
        refreshQueueStatus()
    }

    /// 현재 pending queue를 UserDefaults에 영속화합니다.
    /// 인코딩에 실패하면 기존 저장 상태를 유지합니다.
    private func persistPendingActions() {
        guard let data = try? JSONEncoder().encode(pendingActions) else { return }
        UserDefaults.standard.set(data, forKey: actionQueueStorageKey)
    }

    /// UserDefaults에 저장된 마지막 ACK 스냅샷을 복원합니다.
    /// 저장 데이터가 없거나 복원에 실패하면 기본 ACK 상태를 유지합니다.
    private func loadAckSnapshot() {
        guard let data = UserDefaults.standard.data(forKey: ackSnapshotStorageKey),
              let decoded = try? JSONDecoder().decode(WatchAckSnapshot.self, from: data) else {
            return
        }
        lastAckStatus = decoded.status
        lastAckActionId = decoded.actionId
        lastAckAt = decoded.ackAt
    }

    /// 이전에 이미 표시한 완료 요약 action id를 복원해 중복 sheet 노출을 방지합니다.
    private func loadPresentedCompletionSummaryActionId() {
        lastPresentedCompletionSummaryActionId = UserDefaults.standard.string(
            forKey: presentedCompletionSummaryActionIdStorageKey
        ) ?? ""
    }

    /// 현재 마지막 ACK 상태를 UserDefaults에 영속화합니다.
    /// 인코딩에 실패하면 기존 저장 상태를 유지합니다.
    private func persistAckSnapshot() {
        let snapshot = WatchAckSnapshot(
            status: lastAckStatus,
            actionId: lastAckActionId,
            ackAt: lastAckAt
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: ackSnapshotStorageKey)
    }

    /// 현재 pending queue, ACK, reachability를 카드/시트 공용 상태로 다시 계산합니다.
    private func refreshQueueStatus() {
        queueStatus = .make(
            pendingActions: pendingActions,
            lastSyncAt: lastSyncAt > 0 ? lastSyncAt : nil,
            lastAckStatus: lastAckStatus,
            lastAckActionId: lastAckActionId,
            lastAckAt: lastAckAt,
            isReachable: isReachable,
            syncRecoveryService: syncRecoveryService,
            manualSyncPhase: manualSyncRecoveryPhase,
            nextManualSyncAllowedAt: nextManualSyncAllowedAt
        )
    }

    /// 수동 동기화 요청 후 지정 시간 안에 ACK 또는 최신 context가 오지 않으면 `응답 대기` 상태로 전환합니다.
    /// - Parameter requestedAt: 사용자가 수동 동기화를 누른 시각입니다.
    private func scheduleManualSyncResponseTimeout(requestedAt: TimeInterval) {
        manualSyncResponseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard case .processing(let activeRequestedAt) = self.manualSyncRecoveryPhase,
                  activeRequestedAt == requestedAt else {
                return
            }
            self.manualSyncRecoveryPhase = .waiting(requestedAt: requestedAt)
            self.refreshQueueStatus()
            self.presentBanner(
                title: "응답 대기 중",
                detail: "아직 최신 ACK가 없어 자동 회복을 조금 더 기다리는 중입니다.",
                tone: .warning,
                playsHaptic: false
            )
        }
        manualSyncResponseWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + manualSyncResponseGraceInterval,
            execute: workItem
        )
    }

    /// 수동 동기화 cooldown이 끝나는 시점에 카드/시트 상태를 다시 계산합니다.
    /// - Parameter deadline: 다음 수동 동기화를 허용할 절대 시각입니다.
    private func scheduleManualSyncCooldownRefresh(deadline: TimeInterval) {
        manualSyncCooldownRefreshWorkItem?.cancel()
        let interval = max(deadline - Date().timeIntervalSince1970, 0)
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshQueueStatus()
        }
        manualSyncCooldownRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
    }

    /// 수동 동기화 이후 최신 sync/ACK 시각이 갱신되면 recovery 상태를 완료로 전환합니다.
    /// - Parameter syncTimestamp: recovery 완료를 판단할 최신 동기화 기준 시각입니다.
    private func completeManualSyncRecoveryIfNeeded(syncTimestamp: TimeInterval) {
        guard syncTimestamp > 0 else { return }
        switch manualSyncRecoveryPhase {
        case .processing(let requestedAt), .waiting(let requestedAt):
            guard syncTimestamp >= requestedAt else { return }
            manualSyncResponseWorkItem?.cancel()
            manualSyncResponseWorkItem = nil
            manualSyncRecoveryPhase = .recovered(recoveredAt: Date().timeIntervalSince1970)
            refreshQueueStatus()
            presentBanner(
                title: "동기화 확인 완료",
                detail: "watch와 iPhone 상태를 다시 맞췄어요.",
                tone: .success
            )
            resetManualSyncRecoveryPhaseAfterDelay()
        case .idle, .recovered:
            break
        }
    }

    /// 성공 배너가 지나가면 수동 recovery 상태를 기본값으로 되돌립니다.
    private func resetManualSyncRecoveryPhaseAfterDelay() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if case .recovered = self.manualSyncRecoveryPhase {
                self.manualSyncRecoveryPhase = .idle
                self.refreshQueueStatus()
            }
        }
        manualSyncResponseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }

    /// 마지막 ACK 상태와 시각을 갱신하고 영속화합니다.
    /// - Parameters:
    ///   - status: 사용자에게 보여줄 ACK 상태 문자열입니다.
    ///   - actionId: ACK와 연결된 action id입니다.
    ///   - ackAt: ACK를 받은 시각입니다.
    private func updateAck(status: String, actionId: String, ackAt: TimeInterval?) {
        lastAckStatus = status
        lastAckActionId = actionId
        lastAckAt = ackAt
        persistAckSnapshot()
        refreshQueueStatus()
    }

    /// iPhone이 전달한 완료 요약을 새 action id 기준으로 한 번만 표시합니다.
    /// - Parameter context: iPhone 앱이 내려준 최신 application context입니다.
    private func presentWalkCompletionSummaryIfNeeded(from context: [String: Any]) {
        guard let summary = WatchWalkCompletionSummaryState.make(from: context) else { return }
        guard summary.actionId != lastPresentedCompletionSummaryActionId else { return }
        lastPresentedCompletionSummaryActionId = summary.actionId
        UserDefaults.standard.set(
            summary.actionId,
            forKey: presentedCompletionSummaryActionIdStorageKey
        )
        walkCompletionSummary = summary
    }

    /// pending queue를 가능한 transport 경로로 전달합니다.
    /// reachability가 없으면 queue를 유지하고 개수만 갱신합니다.
    private func flushPendingActions() {
        guard session.activationState == .activated,
              session.isReachable,
              pendingActions.isEmpty == false else {
            pendingActionCount = pendingActions.count
            return
        }

        let queued = pendingActions
        queued.forEach { session.transferUserInfo($0.envelope) }
        pendingActions.removeAll()
        persistPendingActions()
        pendingActionCount = 0
        refreshQueueStatus()
    }

    /// iPhone에서 내려준 최신 application context를 watch 상태로 반영합니다.
    /// action 반영 완료 id가 포함되면 해당 버튼 상태도 성공 상태로 갱신합니다.
    /// - Parameter context: iPhone이 publish한 최신 상태 컨텍스트입니다.
    private func applyContext(_ context: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.contractVersion = context["version"] as? String ?? self.contractVersion
            self.isWalking = context["isWalking"] as? Bool ?? false
            self.walkingTime = context["time"] as? TimeInterval ?? 0
            self.walkingArea = context["area"] as? Double ?? 0
            self.currentWalkPointCount = context["point_count"] as? Int ?? 0
            self.lastSyncAt = context["last_sync_at"] as? TimeInterval ?? 0
            self.petContext = WatchSelectedPetContextState.make(
                from: context,
                fallbackIsWalking: self.isWalking,
                fallbackLastSyncAt: self.lastSyncAt
            )
            self.presentWalkCompletionSummaryIfNeeded(from: context)
            if let appliedActionId = context["last_action_id_applied"] as? String, appliedActionId.isEmpty == false {
                self.applyCompletedState(for: appliedActionId, statusText: context["watch_status"] as? String)
            }
            if let status = context["watch_status"] as? String, status.isEmpty == false {
                let ackAt = self.lastSyncAt > 0 ? self.lastSyncAt : Date().timeIntervalSince1970
                let actionId = (context["last_action_id_applied"] as? String) ?? self.lastAckActionId
                self.updateAck(status: status, actionId: actionId, ackAt: ackAt)
            } else {
                self.refreshQueueStatus()
            }
            self.completeManualSyncRecoveryIfNeeded(
                syncTimestamp: max(self.lastSyncAt, self.lastAckAt ?? 0)
            )
        }
    }

    /// iPhone이 반환한 ACK를 해석해 버튼 상태와 피드백 배너를 갱신합니다.
    /// - Parameters:
    ///   - reply: iPhone replyHandler가 전달한 ACK payload입니다.
    ///   - fallbackActionId: reply에 action id가 없을 때 사용할 기본 action id입니다.
    ///   - fallbackActionType: reply에 action 이름이 없을 때 사용할 기본 액션 종류입니다.
    private func handleAck(
        _ reply: [String: Any],
        fallbackActionId: String,
        fallbackActionType: WatchActionType?
    ) {
        let replyType = reply["type"] as? String
        if let replyType, replyType.isEmpty == false, replyType != watchAckMessageType {
            return
        }
        let status = (reply["status"] as? String) ?? "accepted"
        let actionId = (reply["action_id"] as? String) ?? fallbackActionId
        let actionName = reply["action"] as? String
        let replyMessage = (reply["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let syncedAt = (reply["last_sync_at"] as? TimeInterval) ?? Date().timeIntervalSince1970
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastSyncAt = syncedAt
            self.updateAck(
                status: "ACK \(status)",
                actionId: actionId,
                ackAt: syncedAt
            )
            self.completeManualSyncRecoveryIfNeeded(syncTimestamp: syncedAt)

            let actionType = self.actionTypeByActionId[actionId]
                ?? actionName.flatMap(WatchActionType.init(rawValue:))
                ?? fallbackActionType

            guard let actionType, actionType != .syncState else { return }
            switch status {
            case "accepted":
                self.transition(actionType, to: .acknowledged, resetAfter: 1.4)
                self.presentBanner(
                    title: "전달 완료",
                    detail: replyMessage?.isEmpty == false
                        ? replyMessage!
                        : "\(actionType.baseTitle) 요청을 아이폰으로 전달했어요.",
                    tone: .success,
                    actionEvent: actionType == .addPoint ? .addPointAcknowledged : nil
                )
            case "duplicate":
                self.transition(actionType, to: .duplicateSuppressed, resetAfter: 1.2)
                self.presentBanner(
                    title: "중복 입력 억제",
                    detail: "같은 요청이 이미 처리되어 추가 전송을 막았어요.",
                    tone: .warning,
                    actionEvent: actionType == .addPoint ? .addPointDuplicateSuppressed : nil
                )
            default:
                self.transition(actionType, to: .failed, resetAfter: 1.8)
                self.presentBanner(
                    title: "요청 실패",
                    detail: replyMessage?.isEmpty == false
                        ? replyMessage!
                        : "\(actionType.baseTitle) 요청을 처리하지 못했어요. 다시 시도해 주세요.",
                    tone: .failure,
                    actionEvent: actionType == .addPoint ? .addPointFailed : nil
                )
            }
        }
    }

    /// 현재 액션이 중복 탭 억제 대상인지 판단합니다.
    /// - Parameter action: 사용자가 다시 탭한 액션 종류입니다.
    /// - Returns: 중복 탭을 억제해야 하면 `true`를 반환합니다.
    private func shouldSuppressDuplicateTap(for action: WatchActionType) -> Bool {
        if executionStates[action] == .processing {
            return true
        }
        if executionStates[action] == .queued, action.blocksWhileQueued {
            return true
        }
        if let deadline = cooldownDeadlines[action], deadline > Date() {
            return true
        }
        if action.blocksWhileQueued, pendingActions.contains(where: { $0.action == action.rawValue }) {
            return true
        }
        return false
    }

    /// 액션 상태를 변경하고 필요하면 자동 초기화 타이머를 등록합니다.
    /// - Parameters:
    ///   - action: 상태를 변경할 액션 종류입니다.
    ///   - state: 새 실행 상태입니다.
    ///   - resetAfter: 지정하면 해당 시간 후 상태를 `idle`로 되돌립니다.
    private func transition(
        _ action: WatchActionType,
        to state: WatchActionExecutionState,
        resetAfter: TimeInterval? = nil
    ) {
        executionStates[action] = state
        resetWorkItems[action]?.cancel()
        resetWorkItems[action] = nil
        guard let resetAfter else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.executionStates[action] = .idle
        }
        resetWorkItems[action] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + resetAfter, execute: workItem)
    }

    /// `addPoint` 탭 직후 입력 접수용 촉각을 과도하지 않게 한 번만 재생합니다.
    /// - Parameter action: 사용자가 방금 탭한 워치 액션 종류입니다.
    private func playInputAcknowledgementIfNeeded(for action: WatchActionType) {
        guard action == .addPoint else { return }
        let now = Date().timeIntervalSince1970
        guard now - lastAddPointTapHapticAt >= action.inputAcknowledgementHapticThrottleInterval else { return }
        lastAddPointTapHapticAt = now
        hapticService.playActionEvent(.addPointTapAccepted)
    }

    /// 사용자에게 보여줄 상단 피드백 배너를 갱신하고 필요하면 햅틱을 재생합니다.
    /// - Parameters:
    ///   - title: 배너 타이틀입니다.
    ///   - detail: 배너 세부 설명입니다.
    ///   - tone: 배너 강조 톤입니다.
    ///   - playsHaptic: `true`이면 tone에 맞는 햅틱을 재생합니다.
    ///   - actionEvent: 일반 톤 햅틱 대신 사용할 액션 전용 햅틱 이벤트입니다.
    private func presentBanner(
        title: String,
        detail: String,
        tone: WatchActionFeedbackTone,
        playsHaptic: Bool = true,
        actionEvent: WatchActionHapticEvent? = nil
    ) {
        feedbackBanner = WatchActionFeedbackBanner(title: title, detail: detail, tone: tone)
        if let actionEvent {
            hapticService.playActionEvent(actionEvent)
            return
        }
        if playsHaptic {
            hapticService.playFeedback(for: tone)
        }
    }

    /// iPhone context에서 반영 완료된 action id를 현재 버튼 상태에 연결합니다.
    /// - Parameters:
    ///   - actionId: iPhone이 마지막으로 반영했다고 알려준 action id입니다.
    ///   - statusText: iPhone이 함께 전달한 상태 텍스트입니다.
    private func applyCompletedState(for actionId: String, statusText: String?) {
        guard lastCompletedActionId != actionId else { return }
        guard let actionType = actionTypeByActionId[actionId], actionType != .syncState else { return }
        lastCompletedActionId = actionId
        transition(actionType, to: .completed, resetAfter: 1.8)
        let detail = statusText?.isEmpty == false
            ? statusText!
            : "\(actionType.baseTitle) 요청이 반영되었습니다."
        presentBanner(
            title: "반영 완료",
            detail: detail,
            tone: .success,
            actionEvent: actionType == .addPoint ? .addPointCompleted : nil
        )
    }

    /// 선택 반려견 문맥이 달라 보일 때 iPhone 상태를 다시 요청합니다.
    func refreshPetContext() {
        presentBanner(
            title: "반려견 다시 확인",
            detail: "iPhone의 최신 반려견 상태를 다시 불러옵니다.",
            tone: .processing,
            playsHaptic: false
        )
        sendAction(.syncState)
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("watch session activation failed: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.presentBanner(
                    title: "연결 준비 실패",
                    detail: "워치 연결 준비에 문제가 있어 큐 저장 모드로 동작합니다.",
                    tone: .warning
                )
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isReachable = session.isReachable
            if session.isReachable == false,
               case .processing(let requestedAt) = self.manualSyncRecoveryPhase {
                self.manualSyncRecoveryPhase = .waiting(requestedAt: requestedAt)
            }
            self.refreshQueueStatus()
        }
        applyContext(session.receivedApplicationContext)
        if session.isReachable {
            sendAction(.syncState)
            flushPendingActions()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isReachable = session.isReachable
            if session.isReachable == false,
               case .processing(let requestedAt) = self.manualSyncRecoveryPhase {
                self.manualSyncRecoveryPhase = .waiting(requestedAt: requestedAt)
            }
            self.refreshQueueStatus()
            if session.isReachable == false {
                self.presentBanner(
                    title: "오프라인 전환",
                    detail: "지금 누르는 액션은 큐에 저장했다가 연결되면 자동 전송합니다.",
                    tone: .warning,
                    playsHaptic: false
                )
            }
        }
        if session.isReachable {
            sendAction(.syncState)
            flushPendingActions()
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        applyContext(applicationContext)
    }

    #if os(iOS)
    /// iOS 쪽 세션이 비활성 상태로 전환될 때 도달 가능 상태를 갱신합니다.
    /// - Parameter session: 상태 전환이 발생한 WatchConnectivity 세션입니다.
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
            self?.refreshQueueStatus()
        }
    }

    /// iOS 쪽 세션 비활성 이후 재활성화를 트리거합니다.
    /// - Parameter session: 비활성화된 WatchConnectivity 세션입니다.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
