import WidgetKit
import SwiftUI

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
            WidgetStatusBadge(title: "비회원", color: .orange.opacity(0.2))
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
            WidgetStatusBadge(title: "초기 안내", color: .blue.opacity(0.18))
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
                WidgetStatusBadge(title: statusBadgeText, color: statusBadgeColor)
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
            return "업데이트 \(WidgetFormatting.formattedTime(timestamp: refreshedAt))"
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
