import WidgetKit
import SwiftUI

struct QuestRivalStatusTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: QuestRivalWidgetSnapshot
}

struct QuestRivalStatusTimelineProvider: TimelineProvider {
    private let snapshotStore: QuestRivalWidgetSnapshotStoring

    /// 퀘스트/라이벌 위젯 타임라인 제공자를 생성합니다.
    /// - Parameter snapshotStore: 앱과 공유하는 퀘스트/라이벌 스냅샷 저장소입니다.
    init(snapshotStore: QuestRivalWidgetSnapshotStoring = DefaultQuestRivalWidgetSnapshotStore.shared) {
        self.snapshotStore = snapshotStore
    }

    /// 위젯 갤러리 플레이스홀더 엔트리를 반환합니다.
    /// - Parameter context: 위젯 미리보기 컨텍스트입니다.
    /// - Returns: 기본 퀘스트/라이벌 스냅샷을 포함한 엔트리입니다.
    func placeholder(in context: Context) -> QuestRivalStatusTimelineEntry {
        .init(date: Date(), snapshot: .initial)
    }

    /// 시스템 스냅샷 요청에 현재 저장된 퀘스트/라이벌 스냅샷을 전달합니다.
    /// - Parameters:
    ///   - context: 스냅샷 요청 컨텍스트입니다.
    ///   - completion: 생성한 엔트리를 전달하는 콜백입니다.
    func getSnapshot(in context: Context, completion: @escaping (QuestRivalStatusTimelineEntry) -> Void) {
        completion(.init(date: Date(), snapshot: snapshotStore.load()))
    }

    /// 현재 공유 저장소 기준 타임라인을 생성합니다.
    /// - Parameters:
    ///   - context: 타임라인 생성 컨텍스트입니다.
    ///   - completion: 생성된 타임라인을 전달하는 콜백입니다.
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuestRivalStatusTimelineEntry>) -> Void) {
        let now = Date()
        let entry = QuestRivalStatusTimelineEntry(date: now, snapshot: snapshotStore.load())
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(10 * 60))))
    }
}

struct QuestRivalStatusWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: QuestRivalStatusTimelineEntry

    var body: some View {
        Group {
            switch entry.snapshot.status {
            case .guestLocked:
                guestContent
            case .emptyData:
                emptyContent
            case .memberReady, .offlineCached, .syncDelayed, .claimInFlight, .claimFailed, .claimSucceeded:
                dataContent
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var guestContent: some View {
        let guide = WidgetStatePresentationGuide.presentation(
            for: .guest,
            surface: .questRival
        )
        return VStack(alignment: .leading, spacing: 8) {
            WidgetStatusBadge(title: guide.badgeTitle, color: guide.badgeColor)
            Text(guide.headline)
                .font(.headline)
            Text(guide.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 2)
            Button(intent: OpenQuestDetailIntent()) {
                Label(guide.cta.title, systemImage: guide.cta.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(guide.cta.accessibilityLabel)
            .accessibilityHint(guide.cta.accessibilityHint)
        }
    }

    private var emptyContent: some View {
        let guide = WidgetStatePresentationGuide.presentation(
            for: .empty,
            surface: .questRival,
            fallbackMessage: entry.snapshot.message
        )
        return VStack(alignment: .leading, spacing: 8) {
            WidgetStatusBadge(title: guide.badgeTitle, color: guide.badgeColor)
            Text(guide.headline)
                .font(.headline)
                .lineLimit(2)
            Text(guide.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 2)
            Button(intent: OpenQuestDetailIntent()) {
                Label(guide.cta.title, systemImage: guide.cta.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(guide.cta.accessibilityLabel)
            .accessibilityHint(guide.cta.accessibilityHint)
        }
    }

    private var dataContent: some View {
        let summary = entry.snapshot.summary ?? .zero
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                WidgetStatusBadge(title: statusBadgeTitle, color: statusBadgeColor)
                Spacer(minLength: 0)
                Text(updatedAtText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if family == .systemSmall {
                smallBody(summary: summary)
            } else {
                mediumBody(summary: summary)
            }

            Text(actionStateGuide?.detail ?? entry.snapshot.message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var actionStateGuide: WidgetStatePresentationContent? {
        switch entry.snapshot.status {
        case .offlineCached:
            return WidgetStatePresentationGuide.presentation(
                for: .offline,
                surface: .questRival,
                fallbackMessage: entry.snapshot.message
            )
        case .syncDelayed:
            return WidgetStatePresentationGuide.presentation(
                for: .syncDelayed,
                surface: .questRival,
                fallbackMessage: entry.snapshot.message
            )
        case .memberReady, .guestLocked, .emptyData, .claimInFlight, .claimFailed, .claimSucceeded:
            return nil
        }
    }

    /// 소형 위젯 본문을 렌더링합니다.
    /// - Parameter summary: 퀘스트/라이벌 요약 스냅샷입니다.
    /// - Returns: 퀘스트 진행과 라이벌 순위를 담은 소형 본문 뷰입니다.
    private func smallBody(summary: QuestRivalWidgetSummarySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.questTitle)
                .font(.caption)
                .lineLimit(2)
            ProgressView(value: summary.questProgressRatio)
                .tint(.orange)
            HStack {
                Text(questProgressText(summary))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Text(rivalRankText(summary))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(nextActionCaption(summary))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            primaryActionButton(summary: summary, prominent: true)
        }
    }

    /// 중형 위젯 본문을 렌더링합니다.
    /// - Parameter summary: 퀘스트/라이벌 요약 스냅샷입니다.
    /// - Returns: 퀘스트 진행 메트릭과 액션 버튼을 담은 중형 본문 뷰입니다.
    private func mediumBody(summary: QuestRivalWidgetSummarySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("오늘의 퀘스트")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(summary.questTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("라이벌")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(rivalRankText(summary))
                        .font(.headline)
                }
            }
            ProgressView(value: summary.questProgressRatio)
                .tint(.orange)
            HStack {
                Text(questProgressText(summary))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if shouldShowQuestRemainingText(summary) {
                    Text(questRemainingText(summary))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                } else if summary.rivalRankDelta != 0 {
                    Text("변화 \(summary.rivalRankDelta > 0 ? "+" : "")\(summary.rivalRankDelta)")
                        .font(.caption2)
                        .foregroundStyle(summary.rivalRankDelta > 0 ? .green : .orange)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(nextActionHeadline(summary))
                    .font(.caption.weight(.semibold))
                Text(nextActionCaption(summary))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 8) {
                primaryActionButton(summary: summary, prominent: true)
                secondaryActionButton(summary: summary)
            }
        }
    }

    /// 현재 스냅샷 기준으로 가장 우선해야 할 다음 행동 종류를 계산합니다.
    /// - Parameter summary: 퀘스트/라이벌 위젯 요약 스냅샷입니다.
    /// - Returns: 위젯이 우선 제안해야 할 행동 종류입니다.
    private func primaryActionKind(for summary: QuestRivalWidgetSummarySnapshot) -> WalkWidgetActionKind {
        switch entry.snapshot.status {
        case .claimInFlight, .claimFailed:
            return .openQuestRecovery
        case .claimSucceeded:
            return .openRivalTab
        case .guestLocked:
            return .openQuestDetail
        case .emptyData:
            return .openQuestDetail
        case .offlineCached, .syncDelayed:
            return .openQuestRecovery
        case .memberReady:
            if summary.questClaimable, summary.questInstanceId != nil {
                return .claimQuestReward
            }
            if summary.questProgressRatio >= 0.999 {
                return .openQuestRecovery
            }
            return .openQuestDetail
        }
    }

    /// 현재 스냅샷 기준으로 보조 행동 종류를 계산합니다.
    /// - Parameter summary: 퀘스트/라이벌 위젯 요약 스냅샷입니다.
    /// - Returns: 함께 노출할 보조 행동 종류가 있으면 반환하고, 없으면 `nil`을 반환합니다.
    private func secondaryActionKind(for summary: QuestRivalWidgetSummarySnapshot) -> WalkWidgetActionKind? {
        if actionStateGuide != nil {
            return nil
        }
        switch primaryActionKind(for: summary) {
        case .claimQuestReward:
            return .openRivalTab
        case .openQuestRecovery:
            return .openQuestDetail
        case .openQuestDetail:
            return .openRivalTab
        case .openRivalTab:
            return .openQuestDetail
        case .startWalk, .endWalk, .openWalkTab:
            return nil
        }
    }

    /// 다음 행동 영역의 제목 문구를 계산합니다.
    /// - Parameter summary: 퀘스트/라이벌 위젯 요약 스냅샷입니다.
    /// - Returns: 상태별로 달라지는 다음 행동 제목입니다.
    private func nextActionHeadline(_ summary: QuestRivalWidgetSummarySnapshot) -> String {
        if let guide = actionStateGuide {
            return guide.headline
        }
        switch primaryActionKind(for: summary) {
        case .claimQuestReward:
            return "지금 보상 받을 수 있어요"
        case .openQuestRecovery:
            return entry.snapshot.status == .claimInFlight
                ? "앱에서 수령을 마무리해 주세요"
                : "앱에서 다시 확인이 필요해요"
        case .openQuestDetail:
            return shouldShowQuestRemainingText(summary)
                ? questRemainingText(summary)
                : "퀘스트 상세로 이어서 확인해 보세요"
        case .openRivalTab:
            return "라이벌 순위를 이어서 확인해 보세요"
        case .startWalk, .endWalk, .openWalkTab:
            return "앱에서 확인해 보세요"
        }
    }

    /// 다음 행동 영역의 보조 설명 문구를 계산합니다.
    /// - Parameter summary: 퀘스트/라이벌 위젯 요약 스냅샷입니다.
    /// - Returns: 상태별 CTA와 복구 맥락을 설명하는 보조 문구입니다.
    private func nextActionCaption(_ summary: QuestRivalWidgetSummarySnapshot) -> String {
        if let guide = actionStateGuide {
            return guide.detail
        }
        switch primaryActionKind(for: summary) {
        case .claimQuestReward:
            return "보상 \(summary.questRewardPoint)pt를 지금 수령할 수 있어요."
        case .openQuestRecovery:
            if entry.snapshot.status == .claimInFlight {
                return "위젯 요청은 접수됐어요. 앱에서 처리 결과를 확인하고 마무리해 주세요."
            }
            return "수령이 실패했거나 상태가 어긋났을 수 있어요. 앱에서 복구·재시도해 주세요."
        case .openQuestDetail:
            return shouldShowQuestRemainingText(summary)
                ? "퀘스트 카드에서 남은 진행량과 완료 조건을 바로 확인할 수 있어요."
                : "앱과 위젯 상태가 아직 완전히 맞지 않을 수 있어요."
        case .openRivalTab:
            return "보상 이후 순위 변화와 리그 흐름을 라이벌 탭에서 확인해 보세요."
        case .startWalk, .endWalk, .openWalkTab:
            return "앱에서 현재 상태를 다시 확인해 주세요."
        }
    }

    /// 진행 부족 상태인지 여부를 계산합니다.
    /// - Parameter summary: 퀘스트/라이벌 위젯 요약 스냅샷입니다.
    /// - Returns: 부족분 안내를 노출해야 하면 `true`, 아니면 `false`입니다.
    private func shouldShowQuestRemainingText(_ summary: QuestRivalWidgetSummarySnapshot) -> Bool {
        let shouldEvaluateGap = entry.snapshot.status == .memberReady ||
            entry.snapshot.status == .offlineCached ||
            entry.snapshot.status == .syncDelayed
        guard shouldEvaluateGap else { return false }
        return summary.questClaimable == false && summary.questProgressRatio < 0.999
    }

    /// 목표 달성까지 남은 진행량을 사용자 문구로 변환합니다.
    /// - Parameter summary: 퀘스트/라이벌 위젯 요약 스냅샷입니다.
    /// - Returns: `얼마나 더 필요하다`를 축약한 위젯 문구입니다.
    private func questRemainingText(_ summary: QuestRivalWidgetSummarySnapshot) -> String {
        let remaining = max(summary.questTargetValue - summary.questProgressValue, 0)
        return "보상까지 \(WidgetFormatting.formattedProgressDelta(remaining)) 남음"
    }

    /// primary CTA 버튼을 렌더링합니다.
    /// - Parameters:
    ///   - summary: 퀘스트/라이벌 위젯 요약 스냅샷입니다.
    ///   - prominent: 강조 버튼 스타일 적용 여부입니다.
    /// - Returns: 상태에 맞는 primary CTA 버튼입니다.
    @ViewBuilder
    private func primaryActionButton(
        summary: QuestRivalWidgetSummarySnapshot,
        prominent: Bool
    ) -> some View {
        actionButton(
            kind: primaryActionKind(for: summary),
            title: actionTitle(for: primaryActionKind(for: summary)),
            prominent: prominent
        )
    }

    /// secondary CTA 버튼을 렌더링합니다.
    /// - Parameter summary: 퀘스트/라이벌 위젯 요약 스냅샷입니다.
    /// - Returns: 보조 CTA가 있으면 버튼을 렌더링하고, 없으면 빈 뷰를 렌더링합니다.
    @ViewBuilder
    private func secondaryActionButton(summary: QuestRivalWidgetSummarySnapshot) -> some View {
        if let kind = secondaryActionKind(for: summary) {
            actionButton(kind: kind, title: actionTitle(for: kind), prominent: false)
        }
    }

    /// CTA 종류에 대응하는 버튼 제목을 반환합니다.
    /// - Parameter kind: 렌더링할 CTA 종류입니다.
    /// - Returns: 버튼에 표시할 사용자 문구입니다.
    private func actionTitle(for kind: WalkWidgetActionKind) -> String {
        if kind == .openQuestRecovery, let guide = actionStateGuide {
            return guide.cta.title
        }
        switch kind {
        case .claimQuestReward:
            return "보상 받기"
        case .openQuestDetail:
            return "퀘스트 상세 보기"
        case .openQuestRecovery:
            return "앱에서 마무리"
        case .openRivalTab:
            return "라이벌 보기"
        case .openWalkTab:
            return "앱에서 확인"
        case .startWalk:
            return "산책 시작"
        case .endWalk:
            return "산책 종료"
        }
    }

    /// CTA 종류에 대응하는 SF Symbol 이름을 반환합니다.
    /// - Parameter kind: 렌더링할 CTA 종류입니다.
    /// - Returns: 버튼 라벨에 사용할 시스템 이미지 이름입니다.
    private func actionSymbolName(for kind: WalkWidgetActionKind) -> String {
        if kind == .openQuestRecovery, let guide = actionStateGuide {
            return guide.cta.systemImage
        }
        switch kind {
        case .claimQuestReward:
            return "gift.fill"
        case .openQuestDetail:
            return "list.bullet.rectangle.portrait"
        case .openQuestRecovery:
            return "arrow.trianglehead.clockwise"
        case .openRivalTab:
            return "person.3.fill"
        case .openWalkTab:
            return "arrow.up.right.square"
        case .startWalk:
            return "figure.walk"
        case .endWalk:
            return "stop.fill"
        }
    }

    /// CTA 종류에 맞는 인텐트 버튼을 렌더링합니다.
    /// - Parameters:
    ///   - kind: 렌더링할 CTA 종류입니다.
    ///   - title: 버튼 제목입니다.
    ///   - prominent: 강조 버튼 스타일 적용 여부입니다.
    /// - Returns: 인텐트와 스타일이 적용된 버튼 뷰입니다.
    @ViewBuilder
    private func actionButton(kind: WalkWidgetActionKind, title: String, prominent: Bool) -> some View {
        switch kind {
        case .claimQuestReward:
            if prominent {
                Button(intent: ClaimQuestRewardIntent()) {
                    Label(title, systemImage: actionSymbolName(for: kind))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else {
                Button(intent: ClaimQuestRewardIntent()) {
                    Label(title, systemImage: actionSymbolName(for: kind))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        case .openQuestDetail:
            if prominent {
                Button(intent: OpenQuestDetailIntent()) {
                    Label(title, systemImage: actionSymbolName(for: kind))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else {
                Button(intent: OpenQuestDetailIntent()) {
                    Label(title, systemImage: actionSymbolName(for: kind))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        case .openQuestRecovery:
            if prominent {
                Button(intent: OpenQuestRecoveryIntent()) {
                    Label(title, systemImage: actionSymbolName(for: kind))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else {
                Button(intent: OpenQuestRecoveryIntent()) {
                    Label(title, systemImage: actionSymbolName(for: kind))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        case .openRivalTab:
            Button(intent: OpenRivalTabIntent()) {
                Label(title, systemImage: actionSymbolName(for: kind))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        case .openWalkTab:
            Button(intent: OpenWalkTabIntent()) {
                Label(title, systemImage: actionSymbolName(for: kind))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        case .startWalk:
            if prominent {
                Button(intent: StartWalkIntent()) {
                    Label(title, systemImage: actionSymbolName(for: kind))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(intent: StartWalkIntent()) {
                    Label(title, systemImage: actionSymbolName(for: kind))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        case .endWalk:
            if prominent {
                Button(intent: EndWalkIntent()) {
                    Label(title, systemImage: actionSymbolName(for: kind))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(intent: EndWalkIntent()) {
                    Label(title, systemImage: actionSymbolName(for: kind))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// 퀘스트 진행값을 `현재/목표` 문자열로 변환합니다.
    /// - Parameter summary: 퀘스트 진행 요약을 포함한 스냅샷입니다.
    /// - Returns: 위젯 표시용 진행값 문자열입니다.
    private func questProgressText(_ summary: QuestRivalWidgetSummarySnapshot) -> String {
        let current = Int(summary.questProgressValue.rounded(.down))
        let target = max(1, Int(summary.questTargetValue.rounded(.up)))
        return "진행 \(current)/\(target)"
    }

    /// 라이벌 순위 텍스트를 생성합니다.
    /// - Parameter summary: 라이벌 요약을 포함한 스냅샷입니다.
    /// - Returns: 위젯 표시용 순위 문자열입니다.
    private func rivalRankText(_ summary: QuestRivalWidgetSummarySnapshot) -> String {
        guard let rank = summary.rivalRank else { return "순위 - (\(summary.rivalLeague))" }
        return "#\(rank) (\(summary.rivalLeague))"
    }

    private var updatedAtText: String {
        if let refreshedAt = entry.snapshot.summary?.refreshedAt {
            return "업데이트 \(WidgetFormatting.formattedTime(timestamp: refreshedAt))"
        }
        return "업데이트 -"
    }

    private var statusBadgeTitle: String {
        if let guide = actionStateGuide {
            return guide.badgeTitle
        }
        switch entry.snapshot.status {
        case .memberReady:
            return "실시간"
        case .offlineCached:
            return "오프라인"
        case .syncDelayed:
            return "지연"
        case .claimInFlight:
            return "수령 중"
        case .claimFailed:
            return "수령 실패"
        case .claimSucceeded:
            return "수령 완료"
        case .guestLocked:
            return "비회원"
        case .emptyData:
            return "준비 중"
        }
    }

    private var statusBadgeColor: Color {
        if let guide = actionStateGuide {
            return guide.badgeColor
        }
        switch entry.snapshot.status {
        case .memberReady, .claimSucceeded:
            return .green.opacity(0.20)
        case .offlineCached:
            return .orange.opacity(0.20)
        case .syncDelayed, .claimFailed:
            return .red.opacity(0.18)
        case .claimInFlight:
            return .blue.opacity(0.18)
        case .guestLocked:
            return .orange.opacity(0.20)
        case .emptyData:
            return .blue.opacity(0.18)
        }
    }

}

struct QuestRivalStatusWidget: Widget {
    private let kind = WalkWidgetBridgeContract.questRivalWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuestRivalStatusTimelineProvider()) { entry in
            QuestRivalStatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("퀘스트/라이벌 상태")
        .description("오늘 해야 할 다음 행동과 퀘스트 보상 상태, 라이벌 순위를 빠르게 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
