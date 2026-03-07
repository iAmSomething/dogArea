import AppIntents
import Foundation

struct StartWalkIntent: AppIntent {
    static var title: LocalizedStringResource = "산책 시작"
    static var openAppWhenRun: Bool = true

    /// 위젯에서 산책 시작 액션을 앱 공유 저장소에 기록합니다.
    /// - Returns: 앱 실행 후 소비할 요청을 기록한 인텐트 결과입니다.
    #if compiler(>=6.0)
    func perform() async throws -> some IntentResult & OpensIntent {
        let openURL = preparePendingRoute(kind: .startWalk, contextId: nil)
        return .result(opensIntent: OpenURLIntent(openURL))
    }
    #else
    func perform() async throws -> some IntentResult {
        _ = preparePendingRoute(kind: .startWalk, contextId: nil)
        return .result()
    }
    #endif
}

struct EndWalkIntent: AppIntent {
    static var title: LocalizedStringResource = "산책 종료"
    static var openAppWhenRun: Bool = true

    /// 위젯에서 산책 종료 액션을 앱 공유 저장소에 기록합니다.
    /// - Returns: 앱 실행 후 소비할 요청을 기록한 인텐트 결과입니다.
    #if compiler(>=6.0)
    func perform() async throws -> some IntentResult & OpensIntent {
        let openURL = preparePendingRoute(kind: .endWalk, contextId: nil)
        return .result(opensIntent: OpenURLIntent(openURL))
    }
    #else
    func perform() async throws -> some IntentResult {
        _ = preparePendingRoute(kind: .endWalk, contextId: nil)
        return .result()
    }
    #endif
}

struct OpenWalkTabIntent: AppIntent {
    static var title: LocalizedStringResource = "앱에서 확인"
    static var openAppWhenRun: Bool = true

    /// 위젯에서 지도 탭 진입용 딥링크를 생성합니다.
    /// - Returns: 앱의 지도 탭으로 이동할 인텐트 결과입니다.
    #if compiler(>=6.0)
    func perform() async throws -> some IntentResult & OpensIntent {
        return .result(opensIntent: OpenURLIntent(makeOpenWalkURL()))
    }
    #else
    func perform() async throws -> some IntentResult {
        _ = makeOpenWalkURL()
        return .result()
    }
    #endif

    /// 지도 탭 진입 전용 위젯 딥링크 URL을 생성합니다.
    /// - Returns: 지도 탭 라우팅에 사용할 딥링크 URL입니다.
    private func makeOpenWalkURL() -> URL {
        let route = WalkWidgetActionRequest(
            kind: .openWalkTab,
            actionId: UUID().uuidString.lowercased(),
            source: "widget_open_map",
            contextId: nil,
            requestedAt: Date().timeIntervalSince1970
        )
        return route.asRoute().makeURL() ?? URL(string: "dogarea://widget/walk")!
    }
}

struct ClaimQuestRewardIntent: AppIntent {
    static var title: LocalizedStringResource = "퀘스트 보상 받기"
    static var openAppWhenRun: Bool = true

    /// 위젯에서 퀘스트 보상 수령 액션을 앱 공유 저장소에 기록합니다.
    /// - Returns: 앱 실행 후 소비할 요청을 기록한 인텐트 결과입니다.
    #if compiler(>=6.0)
    func perform() async throws -> some IntentResult & OpensIntent {
        let questInstanceId = DefaultQuestRivalWidgetSnapshotStore.shared.load().summary?.questInstanceId
        let openURL = prepareQuestRewardRoute(contextId: questInstanceId)
        return .result(opensIntent: OpenURLIntent(openURL))
    }
    #else
    func perform() async throws -> some IntentResult {
        let questInstanceId = DefaultQuestRivalWidgetSnapshotStore.shared.load().summary?.questInstanceId
        _ = prepareQuestRewardRoute(contextId: questInstanceId)
        return .result()
    }
    #endif

    /// 퀘스트 보상 수령 요청을 앱 공유 저장소에 기록합니다.
    /// - Parameter contextId: 수령 대상 퀘스트 인스턴스 식별자입니다.
    /// - Returns: 앱으로 전달할 보상 수령 딥링크 URL입니다.
    private func prepareQuestRewardRoute(contextId: String?) -> URL {
        let snapshotStore = DefaultQuestRivalWidgetSnapshotStore.shared
        let current = snapshotStore.load()
        let status: QuestRivalWidgetSnapshotStatus = contextId == nil ? .emptyData : .claimInFlight
        let message: String = contextId == nil
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
        return preparePendingRoute(kind: .claimQuestReward, contextId: contextId)
    }
}

struct OpenRivalTabIntent: AppIntent {
    static var title: LocalizedStringResource = "라이벌 열기"
    static var openAppWhenRun: Bool = true

    /// 위젯에서 라이벌 탭 열기 액션을 앱 공유 저장소에 기록합니다.
    /// - Returns: 앱 실행 후 소비할 요청을 기록한 인텐트 결과입니다.
    #if compiler(>=6.0)
    func perform() async throws -> some IntentResult & OpensIntent {
        let openURL = preparePendingRoute(kind: .openRivalTab, contextId: nil)
        return .result(opensIntent: OpenURLIntent(openURL))
    }
    #else
    func perform() async throws -> some IntentResult {
        _ = preparePendingRoute(kind: .openRivalTab, contextId: nil)
        return .result()
    }
    #endif
}

/// 위젯 액션을 공유 저장소에 기록하고 앱 오픈용 딥링크를 생성합니다.
/// - Parameters:
///   - kind: 앱으로 전달할 위젯 액션 종류입니다.
///   - contextId: 액션에 연결할 선택적 컨텍스트 식별자입니다.
/// - Returns: 앱으로 전달할 딥링크 URL입니다.
private func preparePendingRoute(kind: WalkWidgetActionKind, contextId: String?) -> URL {
    let now = Date()
    let route = WalkWidgetActionRequest(
        kind: kind,
        actionId: UUID().uuidString.lowercased(),
        source: "widget_intent",
        contextId: contextId,
        requestedAt: now.timeIntervalSince1970
    )
    DefaultWalkWidgetActionRequestStore.shared.setPending(route)

    if kind == .startWalk || kind == .endWalk {
        let store = DefaultWalkWidgetSnapshotStore.shared
        let current = store.load()
        store.save(
            .init(
                isWalking: current.isWalking,
                elapsedSeconds: current.elapsedSeconds,
                petName: current.petName,
                status: current.status,
                statusMessage: nil,
                actionState: .pending(kind: kind, now: now),
                updatedAt: now.timeIntervalSince1970
            )
        )
    }

    return route.asRoute().makeURL() ?? URL(string: "dogarea://widget/walk")!
}
