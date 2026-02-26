//
//  ContentsViewModel.swift
//  dogAreaWatch Watch App
//
//  Created by 김태훈 on 12/27/23.
//

import Foundation
import WatchConnectivity

struct WatchActionDTO: Codable, Equatable {
    let action: String
    let actionId: String
    let sentAt: TimeInterval

    var payload: [String: Any] {
        [
            "action": action,
            "action_id": actionId,
            "sent_at": sentAt
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

    private let actionQueueStorageKey = "watch.pendingActions.v1"
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
            action: action.rawValue,
            actionId: UUID().uuidString,
            sentAt: Date().timeIntervalSince1970
        )

        if session.activationState == .activated, session.isReachable {
            session.sendMessage(dto.payload, replyHandler: nil) { [weak self] _ in
                self?.enqueue(dto)
                self?.flushPendingActions()
            }
            return
        }

        enqueue(dto)
        flushPendingActions()
    }

    private func enqueue(_ action: WatchActionDTO) {
        pendingActions.append(action)
        persistPendingActions()
    }

    private func loadPendingActions() {
        guard let data = UserDefaults.standard.data(forKey: actionQueueStorageKey),
              let decoded = try? JSONDecoder().decode([WatchActionDTO].self, from: data) else {
            pendingActions = []
            return
        }
        pendingActions = decoded
    }

    private func persistPendingActions() {
        guard let data = try? JSONEncoder().encode(pendingActions) else { return }
        UserDefaults.standard.set(data, forKey: actionQueueStorageKey)
    }

    private func flushPendingActions() {
        guard session.activationState == .activated,
              session.isReachable,
              pendingActions.isEmpty == false else { return }

        // Flush queued actions when the connection is restored.
        pendingActions.forEach { session.transferUserInfo($0.payload) }
        pendingActions.removeAll()
        persistPendingActions()
    }

    private func applyContext(_ context: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isWalking = context["isWalking"] as? Bool ?? false
            self.walkingTime = context["time"] as? TimeInterval ?? 0
            self.walkingArea = context["area"] as? Double ?? 0
            self.lastSyncAt = context["last_sync_at"] as? TimeInterval ?? 0
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
}
