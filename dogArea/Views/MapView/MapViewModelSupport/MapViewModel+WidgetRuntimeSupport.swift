import Foundation

extension MapViewModel {
    /// 현재 메트릭 수집에 사용할 사용자 식별자를 반환합니다.
    /// - Returns: 유효한 사용자 ID가 있으면 반환하고, 없으면 `nil`을 반환합니다.
    func currentMetricUserId() -> String? {
        guard let raw = userSessionStore.currentUserInfo()?.id, raw.isEmpty == false else {
            return nil
        }
        return raw
    }

    /// 위젯에서 전달된 산책 액션 딥링크를 적용합니다.
    /// - Parameter route: 위젯 액션 종류와 중복 방지 식별자를 담은 라우트입니다.
    func applyWidgetWalkAction(_ route: WalkWidgetActionRoute) {
        guard shouldProcessWidgetAction(actionId: route.actionId) else {
            metricTracker.track(
                .widgetActionDuplicate,
                userKey: currentMetricUserId(),
                payload: ["action": route.kind.rawValue, "source": route.source]
            )
            return
        }

        switch route.kind {
        case .startWalk:
            let widgetPetContext = applyWidgetRequestedPetContextIfNeeded(route)
            guard isWalking == false else {
                walkStatusMessage = "이미 산책이 진행 중입니다."
                metricTracker.track(
                    .widgetActionRejected,
                    userKey: currentMetricUserId(),
                    payload: ["action": route.kind.rawValue, "reason": "already_walking"]
                )
                syncWalkWidgetSnapshot(
                    force: true,
                    statusOverride: .sessionConflict,
                    messageOverride: walkStatusMessage,
                    actionStateOverride: .failed(
                        kind: route.kind,
                        followUp: .openApp,
                        message: "이미 산책 중이에요. 앱에서 현재 세션을 확인해 주세요."
                    )
                )
                return
            }
            guard widgetPetContext.blocksInlineStart == false else {
                walkStatusMessage = "활성 반려견이 없어 앱에서 먼저 확인이 필요합니다."
                metricTracker.track(
                    .widgetActionRejected,
                    userKey: currentMetricUserId(),
                    payload: ["action": route.kind.rawValue, "reason": "no_active_pet"]
                )
                syncWalkWidgetSnapshot(
                    force: true,
                    statusOverride: .error,
                    messageOverride: walkStatusMessage,
                    actionStateOverride: .requiresAppOpen(
                        kind: route.kind,
                        message: "활성 반려견을 찾지 못했어요. 앱에서 반려견을 확인해 주세요."
                    )
                )
                return
            }
            guard isLocationPermissionDenied == false else {
                walkStatusMessage = "위치 권한이 필요합니다. 설정에서 권한을 허용해주세요."
                metricTracker.track(
                    .widgetActionRejected,
                    userKey: currentMetricUserId(),
                    payload: ["action": route.kind.rawValue, "reason": "location_denied"]
                )
                syncWalkWidgetSnapshot(
                    force: true,
                    statusOverride: .locationDenied,
                    messageOverride: walkStatusMessage,
                    actionStateOverride: .failed(
                        kind: route.kind,
                        followUp: .openApp,
                        message: "위치 권한이 필요해요. 앱에서 권한을 확인해 주세요."
                    )
                )
                return
            }
            startWalkNow()
            walkStatusMessage = "위젯에서 산책을 시작했어요."
            metricTracker.track(
                .widgetActionApplied,
                userKey: currentMetricUserId(),
                payload: ["action": route.kind.rawValue, "source": route.source]
            )
            syncWalkWidgetSnapshot(
                force: true,
                actionStateOverride: .succeeded(
                    kind: route.kind,
                    message: "\(widgetPetContext.petName)와 산책을 시작했어요."
                )
            )
            syncWalkLiveActivity(force: true)

        case .endWalk:
            guard isWalking else {
                walkStatusMessage = "종료할 산책 세션이 없습니다."
                metricTracker.track(
                    .widgetActionRejected,
                    userKey: currentMetricUserId(),
                    payload: ["action": route.kind.rawValue, "reason": "no_active_session"]
                )
                syncWalkWidgetSnapshot(
                    force: true,
                    statusOverride: .sessionConflict,
                    messageOverride: walkStatusMessage,
                    actionStateOverride: .failed(
                        kind: route.kind,
                        followUp: .openApp,
                        message: "종료할 산책을 찾지 못했어요. 앱에서 현재 상태를 확인해 주세요."
                    )
                )
                return
            }
            endWalk()
            walkStatusMessage = "위젯에서 산책을 종료했어요."
            metricTracker.track(
                .widgetActionApplied,
                userKey: currentMetricUserId(),
                payload: ["action": route.kind.rawValue, "source": route.source]
            )
            syncWalkWidgetSnapshot(
                force: true,
                actionStateOverride: .succeeded(
                    kind: route.kind,
                    message: "산책을 종료했어요."
                )
            )
            syncWalkLiveActivity(force: true)

        case .claimQuestReward, .openQuestDetail, .openQuestRecovery, .openRivalTab, .openWalkTab:
            metricTracker.track(
                .widgetActionRejected,
                userKey: currentMetricUserId(),
                payload: ["action": route.kind.rawValue, "reason": "unsupported_on_map"]
            )
        }
    }

    /// 현재 산책 상태를 위젯 공유 스냅샷으로 동기화합니다.
    /// - Parameters:
    ///   - force: `true`면 최소 간격 제한 없이 즉시 저장합니다.
    ///   - statusOverride: 상태를 강제로 지정할 때 사용하는 값입니다.
    ///   - messageOverride: 상태 메시지를 강제로 지정할 때 사용하는 값입니다.
    ///   - actionStateOverride: 위젯 액션 상태를 강제로 지정할 때 사용하는 값입니다.
    func syncWalkWidgetSnapshot(
        force: Bool = false,
        statusOverride: WalkWidgetSnapshotStatus? = nil,
        messageOverride: String? = nil,
        actionStateOverride: WalkWidgetActionState? = nil
    ) {
        let now = Date()
        if force == false, now.timeIntervalSince(lastWidgetSnapshotSyncAt) < widgetSnapshotSyncInterval {
            return
        }

        let currentSnapshot = widgetSnapshotStore.load()
        let petContext = currentWalkWidgetPetContext()
        let resolvedStatus = statusOverride ?? (isLocationPermissionDenied ? .locationDenied : .ready)
        let resolvedActionState = resolveWalkWidgetActionState(
            currentSnapshot: currentSnapshot,
            status: resolvedStatus,
            statusMessage: messageOverride,
            actionStateOverride: actionStateOverride,
            now: now
        )
        let snapshot = WalkWidgetSnapshot(
            isWalking: isWalking,
            elapsedSeconds: Int(max(0, time.rounded(.down))),
            petName: petContext.petName,
            petContext: petContext,
            status: resolvedStatus,
            statusMessage: messageOverride,
            actionState: resolvedActionState,
            updatedAt: now.timeIntervalSince1970
        )
        widgetSnapshotStore.save(snapshot)
        lastWidgetSnapshotSyncAt = now
    }

    /// 앱 세션을 정본으로 위젯 액션 상태를 다시 계산합니다.
    /// - Parameters:
    ///   - currentSnapshot: 현재 공유 저장소에 남아 있는 위젯 스냅샷입니다.
    ///   - status: 이번 저장에 반영할 canonical 위젯 상태입니다.
    ///   - statusMessage: canonical 상태에 연결된 보조 메시지입니다.
    ///   - actionStateOverride: 호출자가 강제로 지정한 액션 상태입니다.
    ///   - now: 수렴 판단 기준 시각입니다.
    /// - Returns: 이번 저장에 반영할 최종 액션 상태입니다.
    private func resolveWalkWidgetActionState(
        currentSnapshot: WalkWidgetSnapshot,
        status: WalkWidgetSnapshotStatus,
        statusMessage: String?,
        actionStateOverride: WalkWidgetActionState?,
        now: Date
    ) -> WalkWidgetActionState? {
        guard actionStateOverride == nil else {
            return actionStateOverride
        }

        let previous = currentSnapshot.normalizedActionState
        let resolved = walkWidgetActionConvergenceService.resolve(
            current: previous,
            isWalking: isWalking,
            status: status,
            statusMessage: statusMessage,
            now: now
        )
        trackWalkWidgetActionConvergenceIfNeeded(from: previous, to: resolved)
        return resolved
    }

    /// 위젯 액션 상태가 canonical 세션 기준으로 수렴되거나 escalated 되었을 때 metric을 기록합니다.
    /// - Parameters:
    ///   - previous: 이전에 저장된 액션 상태입니다.
    ///   - current: 이번 저장에서 계산된 액션 상태입니다.
    private func trackWalkWidgetActionConvergenceIfNeeded(
        from previous: WalkWidgetActionState?,
        to current: WalkWidgetActionState?
    ) {
        guard previous != current,
              let previous,
              let current
        else {
            return
        }

        let payload = [
            "action": current.kind.rawValue,
            "fromPhase": previous.phase.rawValue,
            "toPhase": current.phase.rawValue
        ]

        switch (previous.phase, current.phase) {
        case (.pending, .succeeded), (.requiresAppOpen, .succeeded):
            metricTracker.track(
                .widgetActionConverged,
                userKey: currentMetricUserId(),
                payload: payload
            )
        case (.pending, .requiresAppOpen), (.pending, .failed), (.requiresAppOpen, .failed):
            metricTracker.track(
                .widgetActionEscalated,
                userKey: currentMetricUserId(),
                payload: payload
            )
        default:
            break
        }
    }

    /// 앱 활성화 시점에 위젯 스냅샷과 Live Activity를 canonical 산책 상태로 재동기화합니다.
    func reconcileWalkWidgetActionSurfacesOnAppActive() {
        syncWalkWidgetSnapshot(force: true)
        syncWalkLiveActivity(force: true)
    }

    /// 선택 반려견/활성 반려견 목록을 현재 세션 상태와 다시 동기화합니다.
    func reloadSelectedPetContext() {
        let userInfo = userSessionStore.currentUserInfo()
        self.availablePets = userInfo?.pet.filter(\.isActive) ?? []
        let selectedPet = userSessionStore.selectedPet(from: userInfo)
        self.selectedPetId = selectedPet?.petId
        self.selectedPetName = selectedPet?.petName ?? "강아지"
        if isWalking == false {
            self.currentWalkingPetName = self.selectedPetName
        }
        syncWalkWidgetSnapshot(force: true)
        syncWalkLiveActivity(force: true)
        syncWatchContext(force: true)
    }

    /// 현재 산책에 사용할 반려견이 선택되어 있는지 반환합니다.
    /// - Returns: 선택된 반려견 ID가 있으면 `true`, 없으면 `false`입니다.
    var hasSelectedPet: Bool {
        selectedPetId != nil
    }

    /// 산책 시작 전 선택 반려견 제안 규칙을 적용합니다.
    func prepareWalkPetSelectionSuggestion() {
        guard isWalking == false else { return }
        guard let userInfo = userSessionStore.currentUserInfo(),
              userInfo.pet.contains(where: \.isActive) else {
            reloadSelectedPetContext()
            return
        }
        if let suggested = userSessionStore.suggestedPetForWalkStart(from: userInfo, now: Date()),
           suggested.petId != selectedPetId {
            userSessionStore.setSelectedPetId(suggested.petId, source: "walk_start_suggestion")
            metricTracker.track(
                .petSelectionSuggested,
                userKey: currentMetricUserId(),
                payload: [
                    "petId": suggested.petId,
                    "petName": suggested.petName
                ]
            )
            walkStatusMessage = "\(suggested.petName)을(를) 산책 대상으로 제안했어요."
        }
        reloadSelectedPetContext()
    }

    /// 산책 시작 UI에서 선택 반려견을 다음 활성 반려견으로 순환합니다.
    func cycleSelectedPetForWalkStart() {
        guard isWalking == false else { return }
        guard availablePets.count > 1 else { return }

        let currentIndex = availablePets.firstIndex(where: { $0.petId == selectedPetId }) ?? -1
        let nextIndex = (currentIndex + 1) % availablePets.count
        let nextPet = availablePets[nextIndex]
        userSessionStore.setSelectedPetId(nextPet.petId, source: "walk_start_switcher")
        walkStatusMessage = "산책 대상: \(nextPet.petName)"
        reloadSelectedPetContext()
    }

    /// 현재 위젯이 표시해야 할 산책 시작 정책을 계산합니다.
    /// - Returns: 현재 선택 반려견 기준 즉시 시작 또는 카운트다운 시작 정책입니다.
    private func currentWalkWidgetStartPolicy() -> WalkWidgetStartPolicy {
        walkStartCountdownEnabled ? .selectedPetCountdown : .selectedPetImmediate
    }

    /// 현재 위젯·워치에 표시할 반려견 문맥을 계산합니다.
    /// - Returns: 대기 상태의 선택/대체 문맥 또는 산책 중 잠금 문맥입니다.
    func currentWalkWidgetPetContext() -> WalkWidgetPetContext {
        if isWalking {
            return WalkWidgetPetContext(
                petId: polygon.petId ?? selectedPetId,
                petName: currentWalkingPetName,
                source: .walkingLocked,
                startPolicy: currentWalkWidgetStartPolicy(),
                fallbackReason: nil
            )
        }
        return resolveIdleWalkWidgetPetContext(from: userSessionStore.currentUserInfo())
    }

    /// 대기 상태에서 사용할 위젯 반려견 문맥을 계산합니다.
    /// - Parameter userInfo: 현재 로그인 사용자 정보입니다.
    /// - Returns: 선택 반려견, 활성 반려견 대체, 앱 확인 필요 중 하나의 문맥입니다.
    private func resolveIdleWalkWidgetPetContext(from userInfo: UserInfo?) -> WalkWidgetPetContext {
        let startPolicy = currentWalkWidgetStartPolicy()
        guard let userInfo else {
            return WalkWidgetPetContext(
                petId: nil,
                petName: "반려견",
                source: .noActivePet,
                startPolicy: startPolicy,
                fallbackReason: nil
            )
        }

        let activePets = userInfo.pet.filter(\.isActive)
        guard activePets.isEmpty == false else {
            return WalkWidgetPetContext(
                petId: nil,
                petName: "반려견",
                source: .noActivePet,
                startPolicy: startPolicy,
                fallbackReason: nil
            )
        }

        let storedSelectedPetId = userInfo.selectedPetId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let storedSelectedPetId,
           let selectedPet = activePets.first(where: { $0.petId == storedSelectedPetId }) {
            return WalkWidgetPetContext(
                petId: selectedPet.petId,
                petName: selectedPet.petName,
                source: .selectedPet,
                startPolicy: startPolicy,
                fallbackReason: nil
            )
        }

        let fallbackPet = userSessionStore.selectedPet(from: userInfo) ?? activePets.first
        guard let fallbackPet else {
            return WalkWidgetPetContext(
                petId: nil,
                petName: "반려견",
                source: .noActivePet,
                startPolicy: startPolicy,
                fallbackReason: nil
            )
        }

        let fallbackReason = storedSelectedPetId == nil
            ? nil
            : "선택 반려견을 찾지 못해 활성 반려견으로 조정했어요."
        return WalkWidgetPetContext(
            petId: fallbackPet.petId,
            petName: fallbackPet.petName,
            source: fallbackReason == nil ? .selectedPet : .fallbackActivePet,
            startPolicy: startPolicy,
            fallbackReason: fallbackReason
        )
    }

    /// 위젯 산책 시작 요청에 포함된 반려견 문맥을 현재 선택 상태에 반영합니다.
    /// - Parameter route: 고정하려는 반려견 식별자가 포함될 수 있는 위젯 액션 라우트입니다.
    /// - Returns: 선택 상태 반영 후 위젯에 노출해야 할 최신 반려견 문맥입니다.
    private func applyWidgetRequestedPetContextIfNeeded(_ route: WalkWidgetActionRoute) -> WalkWidgetPetContext {
        guard route.kind == .startWalk, isWalking == false else {
            return currentWalkWidgetPetContext()
        }

        return applyRequestedWalkPetContextIfNeeded(route.contextId, source: "widget_start_context")
    }

    /// 요청에 포함된 반려견 식별자를 현재 선택 상태에 반영하고 최신 문맥을 반환합니다.
    /// - Parameters:
    ///   - requestedPetId: 위젯 또는 워치가 고정하려는 반려견 식별자입니다.
    ///   - source: 선택 상태 변경 출처를 식별하는 문자열입니다.
    /// - Returns: 반영 이후 앱이 사용해야 할 최신 반려견 문맥입니다.
    func applyRequestedWalkPetContextIfNeeded(
        _ requestedPetId: String?,
        source: String
    ) -> WalkWidgetPetContext {
        guard isWalking == false else {
            return currentWalkWidgetPetContext()
        }

        let normalizedRequestedPetId = requestedPetId?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalizedRequestedPetId, normalizedRequestedPetId.isEmpty == false else {
            return currentWalkWidgetPetContext()
        }

        let userInfo = userSessionStore.currentUserInfo()
        let activePets = userInfo?.pet.filter(\.isActive) ?? []
        if let matchedPet = activePets.first(where: { $0.petId == normalizedRequestedPetId }) {
            if selectedPetId != matchedPet.petId {
                userSessionStore.setSelectedPetId(matchedPet.petId, source: source)
            }
            reloadSelectedPetContext()
            return currentWalkWidgetPetContext()
        }

        if let fallbackPet = userSessionStore.selectedPet(from: userInfo) ?? activePets.first {
            if selectedPetId != fallbackPet.petId {
                userSessionStore.setSelectedPetId(
                    fallbackPet.petId,
                    source: "\(source)_fallback"
                )
            }
            reloadSelectedPetContext()
            return currentWalkWidgetPetContext()
        }

        reloadSelectedPetContext()
        return currentWalkWidgetPetContext()
    }

    /// 중복 위젯 액션 식별자를 검사하고 최신 식별자를 저장합니다.
    /// - Parameter actionId: 위젯 액션 요청 ID입니다.
    /// - Returns: 처음 처리하는 요청이면 `true`, 중복 요청이면 `false`입니다.
    private func shouldProcessWidgetAction(actionId: String) -> Bool {
        let normalized = actionId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.isEmpty == false else {
            return true
        }
        guard normalized != lastAppliedWidgetActionId else {
            return false
        }
        lastAppliedWidgetActionId = normalized
        preferenceStore.set(normalized, forKey: lastWidgetActionIdKey)
        return true
    }

    /// 현재 자동 종료 정책 기준으로 Live Activity 단계 값을 계산합니다.
    /// - Parameter now: 단계 계산 기준 시각입니다.
    /// - Returns: 무이동 정책(5/12/15분)에 매핑된 단계 값입니다.
    private func currentAutoEndStage(now: Date = Date()) -> WalkLiveActivityAutoEndStage {
        guard isWalking else { return .ended }
        let baseline = lastMovementAt ?? lastPointEventAt ?? startTime
        let inactivity = max(0, now.timeIntervalSince(baseline))
        if inactivity >= inactivityFinalizeInterval { return .autoEnding }
        if inactivity >= inactivityWarningInterval { return .warning }
        if inactivity >= restCandidateInterval { return .restCandidate }
        return .active
    }

    /// 현재 ViewModel 상태를 Live Activity 서비스용 상태 모델로 변환합니다.
    /// - Parameter now: 상태 스냅샷 기준 시각입니다.
    /// - Returns: 세션 식별자, 경과시간, 영역 증가량, 포인트 수, 자동 종료 단계를 포함한 상태입니다.
    private func makeWalkLiveActivityState(now: Date = Date()) -> WalkLiveActivityState {
        WalkLiveActivityState(
            sessionId: polygon.id.uuidString.lowercased(),
            startedAt: startTime.timeIntervalSince1970,
            isWalking: isWalking,
            elapsedSeconds: Int(max(0, time.rounded(.down))),
            pointCount: polygon.locations.count,
            capturedAreaM2: walkHybridContributionSummary.finalAreaM2,
            petName: currentWalkingPetName,
            autoEndStage: currentAutoEndStage(now: now),
            statusMessage: walkStatusMessage,
            updatedAt: now.timeIntervalSince1970
        )
    }

    /// Live Activity 또는 대체 알림 상태를 주기적으로 동기화합니다.
    /// - Parameter force: `true`면 최소 간격 제한 없이 즉시 동기화합니다.
    func syncWalkLiveActivity(force: Bool = false) {
        let now = Date()
        if force == false, now.timeIntervalSince(lastLiveActivitySyncAt) < liveActivitySyncInterval {
            return
        }
        guard liveActivitySyncTask == nil else { return }
        let state = makeWalkLiveActivityState(now: now)
        lastLiveActivitySyncAt = now

        liveActivitySyncTask = Task { [weak self] in
            guard let self else { return }
            let result: WalkLiveActivityServiceResult
            if state.isWalking {
                result = await liveActivityService.sync(state: state)
            } else {
                result = await liveActivityService.end(state: state, dismissImmediately: false)
            }
            await MainActor.run {
                self.applyWalkLiveActivityResult(result)
                self.liveActivitySyncTask = nil
            }
        }
    }

    /// Live Activity 동기화 결과를 배너 메시지 상태에 반영합니다.
    /// - Parameter result: Live Activity 서비스 처리 결과입니다.
    private func applyWalkLiveActivityResult(_ result: WalkLiveActivityServiceResult) {
        switch result {
        case .liveActivity, .ended:
            lastLiveActivityFallbackReason = nil
        case let .fallback(reason):
            guard lastLiveActivityFallbackReason != reason else { return }
            lastLiveActivityFallbackReason = reason
            switch reason {
            case .unsupportedOS:
                walkStatusMessage = "Live Activity 미지원 환경이라 일반 알림으로 대체합니다."
            case .activitiesDisabled:
                walkStatusMessage = "Live Activity가 비활성화되어 일반 알림 + 앱 배너로 안내합니다."
            case .requestFailed:
                walkStatusMessage = "Live Activity 생성에 실패해 일반 알림으로 대체했습니다."
            }
        }
    }
}
