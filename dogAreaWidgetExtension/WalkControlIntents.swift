import AppIntents
import Foundation

struct StartWalkIntent: AppIntent {
    static var title: LocalizedStringResource = "산책 시작"
    static var openAppWhenRun: Bool = true

    /// 위젯에서 산책 시작 액션을 앱 공유 저장소에 기록합니다.
    /// - Returns: 앱 실행 후 소비할 요청을 기록한 인텐트 결과입니다.
    func perform() async throws -> some IntentResult {
        routeToApp(kind: .startWalk)
    }

    /// 공통 위젯 액션 요청을 공유 저장소에 기록합니다.
    /// - Parameter kind: 요청할 위젯 액션 종류입니다.
    /// - Returns: 요청 기록 완료를 나타내는 인텐트 결과입니다.
    private func routeToApp(kind: WalkWidgetActionKind) -> some IntentResult {
        let route = WalkWidgetActionRequest(
            kind: kind,
            actionId: UUID().uuidString.lowercased(),
            source: "widget_intent",
            contextId: nil,
            requestedAt: Date().timeIntervalSince1970
        )
        DefaultWalkWidgetActionRequestStore.shared.setPending(route)

        let store = DefaultWalkWidgetSnapshotStore.shared
        let current = store.load()
        store.save(
            .init(
                isWalking: current.isWalking,
                elapsedSeconds: current.elapsedSeconds,
                petName: current.petName,
                status: .ready,
                statusMessage: "앱에서 요청을 처리 중입니다.",
                updatedAt: Date().timeIntervalSince1970
            )
        )
        return .result()
    }
}

struct EndWalkIntent: AppIntent {
    static var title: LocalizedStringResource = "산책 종료"
    static var openAppWhenRun: Bool = true

    /// 위젯에서 산책 종료 액션을 앱 공유 저장소에 기록합니다.
    /// - Returns: 앱 실행 후 소비할 요청을 기록한 인텐트 결과입니다.
    func perform() async throws -> some IntentResult {
        routeToApp(kind: .endWalk)
    }

    /// 공통 위젯 액션 요청을 공유 저장소에 기록합니다.
    /// - Parameter kind: 요청할 위젯 액션 종류입니다.
    /// - Returns: 요청 기록 완료를 나타내는 인텐트 결과입니다.
    private func routeToApp(kind: WalkWidgetActionKind) -> some IntentResult {
        let route = WalkWidgetActionRequest(
            kind: kind,
            actionId: UUID().uuidString.lowercased(),
            source: "widget_intent",
            contextId: nil,
            requestedAt: Date().timeIntervalSince1970
        )
        DefaultWalkWidgetActionRequestStore.shared.setPending(route)

        let store = DefaultWalkWidgetSnapshotStore.shared
        let current = store.load()
        store.save(
            .init(
                isWalking: current.isWalking,
                elapsedSeconds: current.elapsedSeconds,
                petName: current.petName,
                status: .ready,
                statusMessage: "앱에서 요청을 처리 중입니다.",
                updatedAt: Date().timeIntervalSince1970
            )
        )
        return .result()
    }
}

struct ClaimQuestRewardIntent: AppIntent {
    static var title: LocalizedStringResource = "퀘스트 보상 받기"
    static var openAppWhenRun: Bool = true

    /// 위젯에서 퀘스트 보상 수령 액션을 앱 공유 저장소에 기록합니다.
    /// - Returns: 앱 실행 후 소비할 요청을 기록한 인텐트 결과입니다.
    func perform() async throws -> some IntentResult {
        let snapshotStore = DefaultQuestRivalWidgetSnapshotStore.shared
        let current = snapshotStore.load()
        let questInstanceId = current.summary?.questInstanceId
        let route = WalkWidgetActionRequest(
            kind: .claimQuestReward,
            actionId: UUID().uuidString.lowercased(),
            source: "widget_intent",
            contextId: questInstanceId,
            requestedAt: Date().timeIntervalSince1970
        )
        DefaultWalkWidgetActionRequestStore.shared.setPending(route)

        let status: QuestRivalWidgetSnapshotStatus = questInstanceId == nil ? .emptyData : .claimInFlight
        let message: String = questInstanceId == nil
            ? "수령 가능한 보상을 찾지 못했어요."
            : "앱에서 보상 수령을 처리 중입니다."
        snapshotStore.save(
            QuestRivalWidgetSnapshot(
                status: status,
                message: message,
                summary: current.summary,
                contextKey: current.contextKey,
                updatedAt: Date().timeIntervalSince1970
            )
        )
        return .result()
    }
}

struct OpenRivalTabIntent: AppIntent {
    static var title: LocalizedStringResource = "라이벌 열기"
    static var openAppWhenRun: Bool = true

    /// 위젯에서 라이벌 탭 열기 액션을 앱 공유 저장소에 기록합니다.
    /// - Returns: 앱 실행 후 소비할 요청을 기록한 인텐트 결과입니다.
    func perform() async throws -> some IntentResult {
        let route = WalkWidgetActionRequest(
            kind: .openRivalTab,
            actionId: UUID().uuidString.lowercased(),
            source: "widget_intent",
            contextId: nil,
            requestedAt: Date().timeIntervalSince1970
        )
        DefaultWalkWidgetActionRequestStore.shared.setPending(route)
        return .result()
    }
}
