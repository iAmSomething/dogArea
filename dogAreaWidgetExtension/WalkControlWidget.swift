import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

struct WalkControlTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: WalkWidgetSnapshot
}

struct WalkControlTimelineProvider: TimelineProvider {
    private let snapshotStore: WalkWidgetSnapshotStoring

    /// 위젯 타임라인 제공자를 생성합니다.
    /// - Parameter snapshotStore: 앱과 공유한 산책 스냅샷 저장소입니다.
    init(snapshotStore: WalkWidgetSnapshotStoring = DefaultWalkWidgetSnapshotStore.shared) {
        self.snapshotStore = snapshotStore
    }

    /// 위젯 갤러리에서 사용할 플레이스홀더 엔트리를 반환합니다.
    /// - Parameter context: 위젯 미리보기 컨텍스트입니다.
    /// - Returns: 기본 텍스트를 포함한 타임라인 엔트리입니다.
    func placeholder(in context: Context) -> WalkControlTimelineEntry {
        .init(date: Date(), snapshot: .initial)
    }

    /// 시스템이 빠른 미리보기를 요청할 때 스냅샷 엔트리를 전달합니다.
    /// - Parameters:
    ///   - context: 스냅샷 생성 컨텍스트입니다.
    ///   - completion: 생성된 스냅샷 엔트리를 전달하는 콜백입니다.
    func getSnapshot(in context: Context, completion: @escaping (WalkControlTimelineEntry) -> Void) {
        completion(.init(date: Date(), snapshot: snapshotStore.load()))
    }

    /// 위젯 최신 상태를 반영한 타임라인을 생성합니다.
    /// - Parameters:
    ///   - context: 타임라인 생성 컨텍스트입니다.
    ///   - completion: 타임라인 생성 결과를 전달하는 콜백입니다.
    func getTimeline(in context: Context, completion: @escaping (Timeline<WalkControlTimelineEntry>) -> Void) {
        let now = Date()
        let entry = WalkControlTimelineEntry(date: now, snapshot: snapshotStore.load())
        let next = now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct WalkControlWidgetEntryView: View {
    let entry: WalkControlTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.snapshot.isWalking ? "산책 중" : "산책 대기")
                .font(.headline)
            Text(entry.snapshot.petName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text(Self.formattedElapsed(entry.snapshot.elapsedSeconds))
                    .font(.system(.body, design: .rounded).monospacedDigit())
            }

            if let statusMessage = entry.snapshot.statusMessage,
               statusMessage.isEmpty == false {
                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 2)

            if entry.snapshot.isWalking {
                Button(intent: EndWalkIntent()) {
                    Label("산책 종료", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button(intent: StartWalkIntent()) {
                    Label("산책 시작", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    /// 경과 시간을 `HH:MM:SS` 형식으로 변환합니다.
    /// - Parameter elapsedSeconds: 경과 시간(초)입니다.
    /// - Returns: 위젯 표시용 시간 문자열입니다.
    fileprivate static func formattedElapsed(_ elapsedSeconds: Int) -> String {
        let total = max(0, elapsedSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct WalkControlWidget: Widget {
    private let kind = "com.th.dogArea.walk-control"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WalkControlTimelineProvider()) { entry in
            WalkControlWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("산책 시작/종료")
        .description("홈/잠금 화면에서 산책 시작과 종료를 빠르게 실행합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TerritoryStatusTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: TerritoryWidgetSnapshot
}

struct TerritoryStatusTimelineProvider: TimelineProvider {
    private let snapshotStore: TerritoryWidgetSnapshotStoring

    /// 영역 현황 위젯 타임라인 제공자를 생성합니다.
    /// - Parameter snapshotStore: 앱과 공유하는 영역 위젯 스냅샷 저장소입니다.
    init(snapshotStore: TerritoryWidgetSnapshotStoring = DefaultTerritoryWidgetSnapshotStore.shared) {
        self.snapshotStore = snapshotStore
    }

    /// 위젯 갤러리 플레이스홀더 엔트리를 반환합니다.
    /// - Parameter context: 위젯 미리보기 컨텍스트입니다.
    /// - Returns: 기본 영역 스냅샷을 포함한 엔트리입니다.
    func placeholder(in context: Context) -> TerritoryStatusTimelineEntry {
        .init(date: Date(), snapshot: .initial)
    }

    /// 시스템 스냅샷 요청에 현재 저장된 영역 스냅샷을 전달합니다.
    /// - Parameters:
    ///   - context: 스냅샷 요청 컨텍스트입니다.
    ///   - completion: 생성한 엔트리를 전달하는 콜백입니다.
    func getSnapshot(in context: Context, completion: @escaping (TerritoryStatusTimelineEntry) -> Void) {
        completion(.init(date: Date(), snapshot: snapshotStore.load()))
    }

    /// 현재 공유 저장소 기준 타임라인을 생성합니다.
    /// - Parameters:
    ///   - context: 타임라인 생성 컨텍스트입니다.
    ///   - completion: 생성된 타임라인을 전달하는 콜백입니다.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TerritoryStatusTimelineEntry>) -> Void) {
        let now = Date()
        let entry = TerritoryStatusTimelineEntry(date: now, snapshot: snapshotStore.load())
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(15 * 60))))
    }
}

struct TerritoryStatusWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TerritoryStatusTimelineEntry

    var body: some View {
        Group {
            switch entry.snapshot.status {
            case .guestLocked:
                guestContent
            case .emptyData:
                emptyContent
            case .memberReady, .offlineCached, .syncDelayed:
                dataContent
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var guestContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            badge(title: "비회원", color: .orange.opacity(0.2))
            Text("영역 현황")
                .font(.headline)
            Text("로그인 후 오늘/주간 지표와 방어 예정 타일을 위젯에서 볼 수 있어요.")
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
            badge(title: "초기 안내", color: .blue.opacity(0.18))
            Text("첫 타일 점령을 시작해보세요")
                .font(.headline)
                .lineLimit(2)
            Text(entry.snapshot.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 2)
            Text(updatedAtText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var dataContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                badge(title: statusBadgeText, color: statusBadgeColor)
                Spacer(minLength: 0)
                Text(updatedAtText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if family == .systemSmall {
                smallMetricContent
            } else {
                mediumMetricContent
            }

            if entry.snapshot.status != .memberReady {
                Text(entry.snapshot.message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var smallMetricContent: some View {
        let summary = entry.snapshot.summary ?? .zero
        return VStack(alignment: .leading, spacing: 6) {
            Text("주간 타일")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(summary.weeklyTileCount)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("오늘 \(summary.todayTileCount) · 방어 \(summary.defenseScheduledTileCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var mediumMetricContent: some View {
        let summary = entry.snapshot.summary ?? .zero
        return VStack(alignment: .leading, spacing: 8) {
            Text("영역 현황")
                .font(.headline)

            HStack(spacing: 8) {
                metricTile(title: "오늘", value: summary.todayTileCount, tint: .green)
                metricTile(title: "주간", value: summary.weeklyTileCount, tint: .blue)
                metricTile(title: "방어 예정", value: summary.defenseScheduledTileCount, tint: .orange)
            }
        }
    }

    /// 중형 위젯에서 개별 지표 타일을 렌더링합니다.
    /// - Parameters:
    ///   - title: 타일 상단에 표시할 지표 이름입니다.
    ///   - value: 강조 표시할 지표 값입니다.
    ///   - tint: 지표 강조 색상입니다.
    /// - Returns: 타이틀/숫자/배경 강조가 적용된 지표 타일 뷰입니다.
    private func metricTile(title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 9)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var updatedAtText: String {
        if let refreshedAt = entry.snapshot.summary?.refreshedAt {
            return "업데이트 \(Self.formattedTime(timestamp: refreshedAt))"
        }
        return "업데이트 -"
    }

    private var statusBadgeText: String {
        switch entry.snapshot.status {
        case .memberReady:
            return "실시간"
        case .offlineCached:
            return "오프라인"
        case .syncDelayed:
            return "지연"
        case .guestLocked:
            return "비회원"
        case .emptyData:
            return "초기 안내"
        }
    }

    private var statusBadgeColor: Color {
        switch entry.snapshot.status {
        case .memberReady:
            return .green.opacity(0.2)
        case .offlineCached:
            return .orange.opacity(0.2)
        case .syncDelayed:
            return .red.opacity(0.18)
        case .guestLocked:
            return .orange.opacity(0.2)
        case .emptyData:
            return .blue.opacity(0.18)
        }
    }

    /// 상태 배지를 렌더링합니다.
    /// - Parameters:
    ///   - title: 배지에 표시할 상태 텍스트입니다.
    ///   - color: 배지 배경 색상입니다.
    /// - Returns: 캡슐 형태의 상태 배지 뷰입니다.
    private func badge(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }

    /// 유닉스 타임스탬프를 위젯 표시용 `HH:mm` 문자열로 변환합니다.
    /// - Parameter timestamp: 변환할 유닉스 초 단위 타임스탬프입니다.
    /// - Returns: 사용자 로캘 기준의 시:분 문자열입니다.
    fileprivate static func formattedTime(timestamp: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("HHmm")
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}

struct TerritoryStatusWidget: Widget {
    private let kind = WalkWidgetBridgeContract.territoryWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TerritoryStatusTimelineProvider()) { entry in
            TerritoryStatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("영역 현황")
        .description("오늘/주간 점령 지표와 방어 예정 타일을 빠르게 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#if canImport(ActivityKit)
@available(iOSApplicationExtension 16.1, *)
private struct WalkLiveActivityView: View {
    let context: ActivityViewContext<WalkLiveActivityAttributes>

    private var endRouteURL: URL? {
        WalkWidgetActionRoute(
            kind: .endWalk,
            actionId: "live.end.\(Int(Date().timeIntervalSince1970))",
            source: "live_activity"
        ).makeURL()
    }

    private var openRouteURL: URL? {
        WalkWidgetActionRoute(
            kind: .startWalk,
            actionId: "live.open.\(Int(Date().timeIntervalSince1970))",
            source: "live_activity"
        ).makeURL()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(context.state.petName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(context.state.autoEndStage.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 10) {
                Label(Self.formattedElapsed(context.state.elapsedSeconds), systemImage: "clock")
                    .font(.system(.body, design: .rounded).monospacedDigit())
                Label("포인트 \(context.state.pointCount)", systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
            }
            if let message = context.state.statusMessage,
               message.isEmpty == false {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 8) {
                if #available(iOSApplicationExtension 17.0, *) {
                    Button(intent: EndWalkIntent()) {
                        Label("종료", systemImage: "stop.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else if let endRouteURL {
                    Link(destination: endRouteURL) {
                        Label("종료", systemImage: "stop.fill")
                            .font(.caption)
                    }
                }

                if let openRouteURL {
                    Link(destination: openRouteURL) {
                        Label("앱 열기", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .activityBackgroundTint(Color(.systemBackground))
        .activitySystemActionForegroundColor(.primary)
    }

    /// 경과 시간을 `HH:MM:SS` 형식 문자열로 변환합니다.
    /// - Parameter elapsedSeconds: 경과 시간(초)입니다.
    /// - Returns: Live Activity 표시용 시간 문자열입니다.
    fileprivate static func formattedElapsed(_ elapsedSeconds: Int) -> String {
        let total = max(0, elapsedSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

@available(iOSApplicationExtension 16.1, *)
struct WalkLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkLiveActivityAttributes.self) { context in
            WalkLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.petName)
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.autoEndStage.title)
                        .font(.caption2)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(WalkLiveActivityView.formattedElapsed(context.state.elapsedSeconds))
                        .font(.system(.headline, design: .rounded).monospacedDigit())
                }
            } compactLeading: {
                Text("🐾")
            } compactTrailing: {
                Text("\(context.state.pointCount)")
            } minimal: {
                Image(systemName: "figure.walk")
            }
            .keylineTint(.orange)
        }
    }
}
#endif

#Preview(as: .systemSmall) {
    WalkControlWidget()
} timeline: {
    WalkControlTimelineEntry(
        date: Date(),
        snapshot: .init(
            isWalking: true,
            elapsedSeconds: 824,
            petName: "나무",
            status: .ready,
            statusMessage: nil,
            updatedAt: Date().timeIntervalSince1970
        )
    )
}
