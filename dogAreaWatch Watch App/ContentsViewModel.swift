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

    var envelope: [String: Any] {
        let payload: [String: Any] = [
            "action": action,
            "action_id": actionId,
            "sent_at": sentAt
        ]
        return [
            "version": version,
            "type": type,
            "action": action,
            "action_id": actionId,
            "sent_at": sentAt,
            "payload": payload
        ]
    }
}

enum WatchActionType: String {
    case startWalk = "startWalk"
    case addPoint = "addPoint"
    case endWalk = "endWalk"
    case syncState = "syncState"
}

final class ContentsViewModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isWalking = false
    @Published var walkingTime: TimeInterval = 0
    @Published var walkingArea: Double = 0
    @Published var isReachable = false
    @Published var lastSyncAt: TimeInterval = 0
    @Published var pendingActionCount: Int = 0
    @Published var lastAckStatus: String = "대기"
    @Published var lastAckActionId: String = ""
    @Published var contractVersion: String = "watch.remote.v1"

    private let actionQueueStorageKey = "watch.pendingActions.v1"
    private let watchContractVersion = "watch.remote.v1"
    private let watchActionMessageType = "watch_action"
    private let watchAckMessageType = "watch_ack"
    private var pendingActions: [WatchActionDTO] = []
    private let session = WCSession.default

    override init() {
        super.init()
        loadPendingActions()
        activateSession()
    }

    private func activateSession() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    func sendAction(_ action: WatchActionType) {
        let dto = WatchActionDTO(
            version: watchContractVersion,
            type: watchActionMessageType,
            action: action.rawValue,
            actionId: UUID().uuidString.lowercased(),
            sentAt: Date().timeIntervalSince1970
        )

        if session.activationState == .activated, session.isReachable {
            sendImmediately(dto)
            return
        }

        enqueue(dto)
        flushPendingActions()
    }

    private func sendImmediately(_ action: WatchActionDTO) {
        session.sendMessage(action.envelope, replyHandler: { [weak self] reply in
            self?.handleAck(reply, fallbackActionId: action.actionId)
        }, errorHandler: { [weak self] _ in
            self?.enqueue(action)
            self?.flushPendingActions()
            DispatchQueue.main.async {
                self?.lastAckStatus = "즉시 전송 실패, 큐로 보관"
                self?.lastAckActionId = action.actionId
            }
        })
    }

    private func enqueue(_ action: WatchActionDTO) {
        guard pendingActions.contains(where: { $0.actionId == action.actionId }) == false else { return }
        pendingActions.append(action)
        persistPendingActions()
        pendingActionCount = pendingActions.count
    }

    private func loadPendingActions() {
        guard let data = UserDefaults.standard.data(forKey: actionQueueStorageKey),
              let decoded = try? JSONDecoder().decode([WatchActionDTO].self, from: data) else {
            pendingActions = []
            pendingActionCount = 0
            return
        }
        pendingActions = decoded
        pendingActionCount = decoded.count
    }

    private func persistPendingActions() {
        guard let data = try? JSONEncoder().encode(pendingActions) else { return }
        UserDefaults.standard.set(data, forKey: actionQueueStorageKey)
    }

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
        lastAckStatus = "큐 전송 등록 \(queued.count)건"
    }

    private func applyContext(_ context: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.contractVersion = context["version"] as? String ?? self.contractVersion
            self.isWalking = context["isWalking"] as? Bool ?? false
            self.walkingTime = context["time"] as? TimeInterval ?? 0
            self.walkingArea = context["area"] as? Double ?? 0
            self.lastSyncAt = context["last_sync_at"] as? TimeInterval ?? 0
            if let appliedActionId = context["last_action_id_applied"] as? String, appliedActionId.isEmpty == false {
                self.lastAckActionId = appliedActionId
            }
            if let status = context["watch_status"] as? String, status.isEmpty == false {
                self.lastAckStatus = status
            }
        }
    }

    private func handleAck(_ reply: [String: Any], fallbackActionId: String) {
        let replyType = reply["type"] as? String
        if let replyType, replyType.isEmpty == false, replyType != watchAckMessageType {
            return
        }
        let status = (reply["status"] as? String) ?? "accepted"
        let actionId = (reply["action_id"] as? String) ?? fallbackActionId
        let syncedAt = (reply["last_sync_at"] as? TimeInterval) ?? Date().timeIntervalSince1970
        DispatchQueue.main.async { [weak self] in
            self?.lastAckStatus = "ACK \(status)"
            self?.lastAckActionId = actionId
            self?.lastSyncAt = syncedAt
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("watch session activation failed: \(error.localizedDescription)")
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
        }
        applyContext(session.receivedApplicationContext)
        if session.isReachable {
            sendAction(.syncState)
            flushPendingActions()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
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
        }
    }

    /// iOS 쪽 세션 비활성 이후 재활성화를 트리거합니다.
    /// - Parameter session: 비활성화된 WatchConnectivity 세션입니다.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
