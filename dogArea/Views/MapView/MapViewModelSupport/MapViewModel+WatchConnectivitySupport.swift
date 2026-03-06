import Foundation
import WatchConnectivity

extension MapViewModel {
    /// 현재 산책 상태를 워치 application context로 발행합니다.
    func publishWatchState() {
        if Thread.isMainThread == false {
            DispatchQueue.main.async { [weak self] in
                self?.publishWatchState()
            }
            return
        }
        guard let watchSession = resolveWatchContextSession(updateStatusText: false) else { return }
        let context: [String: Any] = [
            "isWalking": isWalking,
            "time": time,
            "area": calculateArea()
        ]
        try? watchSession.updateApplicationContext(context)
    }

    /// WatchConnectivity 세션을 초기화하고 첫 컨텍스트 동기화를 시도합니다.
    func setupWatchConnectivity() {
        guard let watchSession else { return }
        watchSession.delegate = self
        watchSession.activate()
        self.syncWatchContext(force: true)
    }

    /// 워치 상태 컨텍스트를 최소 간격 제약을 두고 동기화합니다.
    /// - Parameter force: `true`면 1초 스로틀을 무시하고 즉시 갱신합니다.
    func syncWatchContext(force: Bool = false) {
        if Thread.isMainThread == false {
            DispatchQueue.main.async { [weak self] in
                self?.syncWatchContext(force: force)
            }
            return
        }
        guard let watchSession = resolveWatchContextSession(updateStatusText: true) else { return }

        let now = Date()
        if force == false, now.timeIntervalSince(lastWatchContextSyncAt) < 1.0 {
            return
        }

        let context: [String: Any] = [
            "version": WatchContract.version,
            "type": "watch_state",
            "isWalking": self.isWalking,
            "time": self.time,
            "area": self.polygon.walkingArea,
            "last_sync_at": now.timeIntervalSince1970,
            "watch_status": self.watchSyncStatusText,
            "last_action_id_applied": self.lastAppliedWatchActionId
        ]

        do {
            try watchSession.updateApplicationContext(context)
            self.lastWatchContextSyncAt = now
            self.watchSyncStatusText = "워치 동기화 \(Self.statusTimeString(from: now))"
        } catch {
            self.watchSyncStatusText = "워치 동기화 실패"
            print("watch context update failed: \(error.localizedDescription)")
        }
    }

    /// 저장소에 남아 있는 처리 완료 워치 액션 ID 목록을 불러옵니다.
    func loadProcessedWatchActions() {
        let stored = preferenceStore.stringArray(forKey: processedWatchActionStorageKey)
        self.processedWatchActionOrder = stored
        self.processedWatchActionIds = Set(stored)
    }

    /// 워치 액션 deduplication 집합을 저장소에 반영합니다.
    private func persistProcessedWatchActions() {
        preferenceStore.set(self.processedWatchActionOrder, forKey: processedWatchActionStorageKey)
    }

    /// 워치 컨텍스트 업데이트 가능 상태를 확인하고 사용 가능한 세션을 반환합니다.
    /// - Parameter updateStatusText: 게이트 실패 시 `watchSyncStatusText`를 즉시 갱신할지 여부입니다.
    /// - Returns: 업데이트 가능하면 활성화된 `WCSession`, 불가능하면 `nil`입니다.
    private func resolveWatchContextSession(updateStatusText: Bool) -> WCSession? {
        guard let watchSession else {
            if updateStatusText, watchSyncStatusText != "워치 연결 미지원" {
                watchSyncStatusText = "워치 연결 미지원"
            }
            return nil
        }

        guard watchSession.activationState == .activated else {
            if updateStatusText, watchSyncStatusText != "워치 연결 대기" {
                watchSyncStatusText = "워치 연결 대기"
            }
            return nil
        }

        #if os(iOS)
        guard watchSession.isPaired else {
            if updateStatusText, watchSyncStatusText != "워치 미페어링" {
                watchSyncStatusText = "워치 미페어링"
            }
            return nil
        }

        guard watchSession.isWatchAppInstalled else {
            if updateStatusText, watchSyncStatusText != "워치 앱 미설치" {
                watchSyncStatusText = "워치 앱 미설치"
            }
            return nil
        }
        #endif

        return watchSession
    }

    /// 이미 처리한 워치 액션인지 검사하고 deduplication 상태를 갱신합니다.
    /// - Parameter actionId: 워치가 보낸 액션 식별자입니다.
    /// - Returns: 처음 처리하는 요청이면 `true`, 중복 요청이면 `false`입니다.
    private func shouldProcessWatchAction(actionId: String) -> Bool {
        guard processedWatchActionIds.contains(actionId) == false else {
            return false
        }
        processedWatchActionIds.insert(actionId)
        processedWatchActionOrder.append(actionId)
        if processedWatchActionOrder.count > maxProcessedWatchActions {
            let overflow = processedWatchActionOrder.count - maxProcessedWatchActions
            let removed = Array(processedWatchActionOrder.prefix(overflow))
            processedWatchActionOrder.removeFirst(overflow)
            removed.forEach { processedWatchActionIds.remove($0) }
        }
        persistProcessedWatchActions()
        return true
    }

    /// 워치 payload를 파싱하고 처리 결과에 맞는 ACK payload를 반환합니다.
    /// - Parameter payload: 워치가 보낸 원본 메시지 또는 userInfo입니다.
    /// - Returns: 처리 결과를 담은 ACK payload이며, 파싱 실패 시 `nil`을 반환합니다.
    @discardableResult
    private func handleWatchPayload(_ payload: [String: Any]) -> [String: Any]? {
        if Thread.isMainThread == false {
            return DispatchQueue.main.sync { [weak self] in
                self?.handleWatchPayload(payload)
            }
        }
        guard let envelope = parseWatchEnvelope(from: payload) else { return nil }
        let actionName = envelope.action.rawValue
        let sentAtLabel: String = {
            guard let sentAt = envelope.sentAt else { return "" }
            return " sent:\(Int(sentAt))"
        }()
        latestWatchActionText = "워치 \(actionName) 수신 \(Self.statusTimeString(from: Date()))"
        metricTracker.track(
            .watchActionReceived,
            userKey: currentMetricUserId(),
            payload: [
                "action": actionName,
                "version": envelope.version + sentAtLabel
            ]
        )
        if shouldProcessWatchAction(actionId: envelope.actionId) == false {
            metricTracker.track(
                .watchActionDuplicate,
                userKey: currentMetricUserId(),
                payload: [
                    "action": actionName,
                    "actionId": envelope.actionId
                ]
            )
            return [
                "version": WatchContract.version,
                "type": WatchContract.ackType,
                "status": "duplicate",
                "action": actionName,
                "action_id": envelope.actionId,
                "last_sync_at": Date().timeIntervalSince1970
            ]
        }
        metricTracker.track(
            .watchActionProcessed,
            userKey: currentMetricUserId(),
            payload: [
                "action": actionName,
                "actionId": envelope.actionId
            ]
        )
        self.applyWatchAction(envelope)
        return [
            "version": WatchContract.version,
            "type": WatchContract.ackType,
            "status": "accepted",
            "action": actionName,
            "action_id": envelope.actionId,
            "last_sync_at": Date().timeIntervalSince1970
        ]
    }

    /// 워치 원본 payload를 타입 안전한 액션 엔벌로프로 변환합니다.
    /// - Parameter payload: 워치가 보낸 원본 payload입니다.
    /// - Returns: 파싱된 액션 엔벌로프이며, 계약에 맞지 않으면 `nil`을 반환합니다.
    private func parseWatchEnvelope(from payload: [String: Any]) -> WatchActionEnvelope? {
        let version = (payload["version"] as? String) ?? "watch.legacy.v0"
        if let type = payload["type"] as? String,
           type.isEmpty == false,
           type != WatchContract.actionType {
            return nil
        }
        let nestedPayload = payload["payload"] as? [String: Any]
        let actionPayload = nestedPayload ?? payload

        guard let rawAction = (actionPayload["action"] as? String) ?? (payload["action"] as? String),
              let action = WatchIncomingAction(rawValue: rawAction) else {
            return nil
        }
        let actionId: String = {
            if let id = (actionPayload["action_id"] as? String) ?? (payload["action_id"] as? String),
               id.isEmpty == false {
                return id
            }
            if let sentAt = (actionPayload["sent_at"] as? TimeInterval) ?? (payload["sent_at"] as? TimeInterval) {
                return "\(rawAction):\(Int(sentAt * 1000.0))"
            }
            return UUID().uuidString.lowercased()
        }()
        let sentAt = (actionPayload["sent_at"] as? TimeInterval) ?? (payload["sent_at"] as? TimeInterval)
        return WatchActionEnvelope(version: version, action: action, actionId: actionId, sentAt: sentAt)
    }

    /// 파싱된 워치 액션을 현재 산책 세션 상태에 반영합니다.
    /// - Parameter envelope: 처리할 워치 액션 엔벌로프입니다.
    private func applyWatchAction(_ envelope: WatchActionEnvelope) {
        let action = envelope.action
        switch action {
        case .startWalk:
            if self.isWalking == false {
                self.startWalkNow()
                self.latestWatchActionText = "워치 시작 반영 \(Self.statusTimeString(from: Date()))"
                self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action.rawValue])
            }
        case .addPoint:
            if self.isWalking {
                if let location = self.location {
                    self.appendWalkPoint(from: location, recordedAt: Date(), source: .watch)
                    self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action.rawValue])
                }
            }
        case .endWalk:
            if self.isWalking {
                self.endWalk()
                self.latestWatchActionText = "워치 종료 반영 \(Self.statusTimeString(from: Date()))"
                self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action.rawValue])
            }
        case .syncState:
            self.latestWatchActionText = "워치 상태 재동기화 \(Self.statusTimeString(from: Date()))"
        }
        self.lastAppliedWatchActionId = envelope.actionId
        self.syncWatchContext(force: true)
    }
}

// MARK: - WatchConnectivity
extension MapViewModel {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let error {
                print("watch activation failed: \(error.localizedDescription)")
                return
            }
            self.syncWatchContext(force: true)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.syncWatchContext(force: true)
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String : Any],
        replyHandler: @escaping ([String : Any]) -> Void
    ) {
        let ack = self.handleWatchPayload(message) ?? [
            "version": WatchContract.version,
            "type": WatchContract.ackType,
            "status": "ignored",
            "last_sync_at": Date().timeIntervalSince1970
        ]
        replyHandler(ack)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        self.handleWatchPayload(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        self.handleWatchPayload(userInfo)
    }
}
