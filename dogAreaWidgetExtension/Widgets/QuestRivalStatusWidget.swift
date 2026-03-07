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
        VStack(alignment: .leading, spacing: 8) {
            WidgetStatusBadge(title: "비회원", color: .orange.opacity(0.2))
            Text("퀘스트/라이벌 위젯")
                .font(.headline)
            Text("로그인 후 오늘의 퀘스트 진행률과 라이벌 순위를 빠르게 확인할 수 있어요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 2)
            Text("앱에서 로그인")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetStatusBadge(title: "준비 중", color: .blue.opacity(0.18))
            Text("퀘스트 데이터를 준비 중입니다")
                .font(.headline)
                .lineLimit(2)
            Text(entry.snapshot.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 2)
            Button(intent: OpenRivalTabIntent()) {
                Label("라이벌 열기", systemImage: "person.3.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
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

            Text(entry.snapshot.message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
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
            if summary.questClaimable, summary.questInstanceId != nil {
                Button(intent: ClaimQuestRewardIntent()) {
                    Label("보상 받기", systemImage: "gift.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else {
                Button(intent: OpenRivalTabIntent()) {
                    Label("라이벌", systemImage: "person.3.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
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
                if summary.rivalRankDelta != 0 {
                    Text("변화 \(summary.rivalRankDelta > 0 ? "+" : "")\(summary.rivalRankDelta)")
                        .font(.caption2)
                        .foregroundStyle(summary.rivalRankDelta > 0 ? .green : .orange)
                }
            }
            HStack(spacing: 8) {
                Button(intent: ClaimQuestRewardIntent()) {
                    Label("보상 받기", systemImage: "gift.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(summary.questClaimable == false || summary.questInstanceId == nil)

                Button(intent: OpenRivalTabIntent()) {
                    Label("라이벌", systemImage: "person.3.fill")
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
        .description("오늘의 퀘스트 진행률과 보상, 라이벌 순위를 빠르게 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
