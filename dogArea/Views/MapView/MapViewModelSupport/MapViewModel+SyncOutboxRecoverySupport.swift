import Foundation

extension MapViewModel {
    /// UI 테스트에서 영구 실패 복구 배너를 강제로 노출해야 하는지 판정합니다.
    /// - Returns: `-UITest.MapSyncOutboxPermanentFailurePreview` 인자가 포함되면 `true`를 반환합니다.
    static func shouldForceSyncOutboxPermanentFailurePreviewForUITest() -> Bool {
        ProcessInfo.processInfo.arguments.contains("-UITest.MapSyncOutboxPermanentFailurePreview")
    }

    /// 현재 outbox 영구 실패 세션을 로컬 기록과 대조해 복구 배너 요약을 갱신합니다.
    func refreshSyncOutboxRecoveryOverview() {
        if Self.shouldForceSyncOutboxPermanentFailurePreviewForUITest() {
            applyUITestSyncOutboxPermanentFailurePreviewIfNeeded()
            return
        }

        let overview = SyncOutboxPermanentFailurePresentationService().makeOverview(
            sessionSnapshots: syncOutbox.permanentFailureSessions(),
            localPolygons: walkRepository.fetchPolygons()
        )
        syncOutboxRecoveryOverview = overview
    }

    /// 복구 가능한 영구 실패 세션을 최신 로컬 기록 기준으로 다시 큐잉합니다.
    func rebuildRecoverableSyncOutboxSessions() {
        if Self.shouldForceSyncOutboxPermanentFailurePreviewForUITest() {
            syncOutboxRecoveryOverview = makeUITestSyncOutboxRecoveryOverview(
                rebuildableCount: 0,
                archiveableCount: 1,
                supportCount: 1
            )
            syncOutboxPermanentFailureCount = 2
            syncOutboxPendingCount = 3
            syncOutboxLastErrorCodeText = SyncOutboxErrorCode.sessionInvalidPetReference.rawValue
            syncRecoveryToastMessage = "1건을 현재 기록 기준으로 다시 만들었어요."
            return
        }

        guard let overview = syncOutboxRecoveryOverview,
              overview.rebuildableSessionIds.isEmpty == false else {
            return
        }

        let polygonsBySessionId = Dictionary(uniqueKeysWithValues: walkRepository.fetchPolygons().map {
            ($0.id.uuidString.lowercased(), $0)
        })
        let ownerUserId = currentMetricUserId()
        let sessionDTOs = overview.rebuildableSessionIds.compactMap { sessionId -> WalkSessionBackfillDTO? in
            guard let polygon = polygonsBySessionId[sessionId] else { return nil }
            return WalkBackfillDTOConverter.makeSessionDTO(
                from: polygon,
                ownerUserId: ownerUserId,
                petId: polygon.canonicalPetId,
                sourceDevice: "ios",
                hasImage: polygon.binaryImage != nil
            )
        }

        let enqueuedStageCount = syncOutbox.replaceStagesForSessions(sessionDTOs)
        refreshSyncOutboxSummary()
        syncRecoveryToastMessage = enqueuedStageCount > 0
            ? "\(sessionDTOs.count)건을 현재 기록 기준으로 다시 만들었어요."
            : "다시 만들 수 있는 기록을 찾지 못했어요."
        if enqueuedStageCount > 0 {
            flushSyncOutboxIfNeeded(force: true)
        }
    }

    /// 로컬 기록은 유지하되 자동 복구가 어려운 영구 실패 세션을 동기화 목록에서만 정리합니다.
    func archiveCleanupEligibleSyncOutboxSessions() {
        if Self.shouldForceSyncOutboxPermanentFailurePreviewForUITest() {
            syncOutboxRecoveryOverview = makeUITestSyncOutboxRecoveryOverview(
                rebuildableCount: 1,
                archiveableCount: 0,
                supportCount: 1
            )
            syncOutboxPermanentFailureCount = 2
            syncOutboxPendingCount = 0
            syncOutboxLastErrorCodeText = SyncOutboxErrorCode.schemaMismatch.rawValue
            syncRecoveryToastMessage = "1건을 동기화 목록에서 정리했어요. 기록은 이 기기에 남아 있어요."
            return
        }

        guard let overview = syncOutboxRecoveryOverview,
              overview.archiveableSessionIds.isEmpty == false else {
            return
        }

        let removedCount = syncOutbox.archivePermanentFailures(
            walkSessionIds: Set(overview.archiveableSessionIds)
        )
        refreshSyncOutboxSummary()
        syncRecoveryToastMessage = removedCount > 0
            ? "\(overview.archiveableSessionIds.count)건을 동기화 목록에서 정리했어요. 기록은 이 기기에 남아 있어요."
            : "정리할 영구 실패 기록을 찾지 못했어요."
    }

    /// 영구 실패 세션 문의 메일을 작성할 `mailto:` URL을 생성합니다.
    /// - Returns: 문의 메일 URL이며, 현재 문의 대상이 없으면 `nil`입니다.
    func syncOutboxSupportMailURL() -> URL? {
        guard let overview = syncOutboxRecoveryOverview else { return nil }
        return SyncOutboxPermanentFailurePresentationService().makeSupportMailURL(
            overview: overview,
            currentUserId: currentMetricUserId() ?? userSessionStore.currentUserInfo()?.id,
            supportEmail: SettingsAppMetadata.placeholder.supportEmail
        )
    }

    /// UI 테스트에서 영구 실패 배너를 재현할 수 있도록 더미 요약을 주입합니다.
    func applyUITestSyncOutboxPermanentFailurePreviewIfNeeded() {
        syncOutboxRecoveryOverview = makeUITestSyncOutboxRecoveryOverview(
            rebuildableCount: 1,
            archiveableCount: 1,
            supportCount: 1
        )
        syncOutboxPendingCount = 0
        syncOutboxPermanentFailureCount = 3
        syncOutboxLastErrorCodeText = SyncOutboxErrorCode.schemaMismatch.rawValue
    }

    /// UI 테스트용 영구 실패 요약 모델을 생성합니다.
    /// - Parameters:
    ///   - rebuildableCount: 자동 재생성이 가능한 세션 수입니다.
    ///   - archiveableCount: 동기화 목록 정리만 가능한 세션 수입니다.
    ///   - supportCount: 문의가 필요한 세션 수입니다.
    /// - Returns: 배너 렌더링에 사용할 테스트용 요약 모델입니다.
    private func makeUITestSyncOutboxRecoveryOverview(
        rebuildableCount: Int,
        archiveableCount: Int,
        supportCount: Int
    ) -> SyncOutboxPermanentFailureOverview {
        let rebuildable = (0..<rebuildableCount).map { "rebuild-\($0)" }
        let archiveable = (0..<archiveableCount).map { "archive-\($0)" }
        let support = (0..<supportCount).map { "support-\($0)" }
        let total = rebuildableCount + archiveableCount + supportCount

        var messageSegments: [String] = []
        if rebuildableCount > 0 {
            messageSegments.append("\(rebuildableCount)건은 현재 기록 기준으로 다시 만들어 복구할 수 있어요.")
        }
        if archiveableCount > 0 {
            messageSegments.append("\(archiveableCount)건은 기기 기록은 남기고 동기화 목록에서만 정리할 수 있어요.")
        }
        if supportCount > 0 {
            messageSegments.append("\(supportCount)건은 계정 또는 소유권 확인이 필요해 문의로 넘기는 편이 안전해요.")
        }

        return SyncOutboxPermanentFailureOverview(
            totalSessionCount: total,
            rebuildableSessionIds: rebuildable,
            archiveableSessionIds: archiveable,
            supportRequiredSessionIds: support,
            title: "동기화 정리가 필요한 기록 \(total)건",
            message: messageSegments.joined(separator: " "),
            detailLines: [
                "예전 형식으로 저장된 기록은 다시 만들어 복구할 수 있어요.",
                "반려견 참조가 없는 기록은 로컬 보관만 유지하고 목록에서 정리할 수 있어요.",
                "계정 또는 소유권 충돌은 문의로 넘겨 원인을 확인해야 해요."
            ],
            representativeErrorCode: supportCount > 0 ? .sessionOwnershipConflict : .schemaMismatch
        )
    }
}
