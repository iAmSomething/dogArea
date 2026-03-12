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

    private var layoutBudget: WidgetSurfaceLayoutBudget {
        .resolve(for: family)
    }

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
        .widgetURL(territoryWidgetURL)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var territoryWidgetURL: URL? {
        TerritoryWidgetDeepLinkRoute(
            destination: .goalDetail,
            source: "territory_widget",
            status: entry.snapshot.status
        )
        .makeURL()
    }

    private var guestContent: some View {
        let guide = WidgetStatePresentationGuide.presentation(
            for: .guest,
            surface: .territory
        )
        return WidgetSurfacePage(budget: layoutBudget) {
            WidgetStatusBadge(title: guide.badgeTitle, color: guide.badgeColor, budget: layoutBudget)
        } body: {
            Text(guide.headline)
                .font(.headline)
                .lineLimit(layoutBudget.headlineLineLimit)
            Text(guide.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(layoutBudget.detailLineLimit)
        } footer: {
            WidgetStateCTAView(cta: guide.cta, budget: layoutBudget)
        }
    }

    private var emptyContent: some View {
        let guide = WidgetStatePresentationGuide.presentation(
            for: .empty,
            surface: .territory
        )
        return WidgetSurfacePage(budget: layoutBudget) {
            WidgetStatusBadge(title: guide.badgeTitle, color: guide.badgeColor, budget: layoutBudget)
        } body: {
            Text(guide.headline)
                .font(.headline)
                .lineLimit(layoutBudget.headlineLineLimit)
            Text(guide.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(layoutBudget.detailLineLimit)
        } footer: {
            WidgetStateCTAView(cta: guide.cta, budget: layoutBudget, tint: .blue)
        }
    }

    private var dataContent: some View {
        WidgetSurfacePage(budget: layoutBudget) {
            HStack(alignment: .top, spacing: 8) {
                WidgetStatusBadge(title: statusBadgeText, color: statusBadgeColor, budget: layoutBudget)
                if layoutBudget.prefersCompactFormatting == false {
                    Spacer(minLength: 0)
                    Text(updatedAtText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } body: {
            if family == .systemSmall {
                smallMetricContent
            } else {
                ViewThatFits(in: .vertical) {
                    mediumMetricContent
                    mediumMetricCompactContent
                }
            }
        } footer: {
            if let guide = nonReadyStateGuide {
                stateGuideFooterView(
                    guide,
                    tint: entry.snapshot.status == .syncDelayed ? .red : .orange
                )
            }
        }
    }

    private var nonReadyStateGuide: WidgetStatePresentationContent? {
        switch entry.snapshot.status {
        case .offlineCached:
            return WidgetStatePresentationGuide.presentation(
                for: .offline,
                surface: .territory,
                fallbackMessage: entry.snapshot.message
            )
        case .syncDelayed:
            return WidgetStatePresentationGuide.presentation(
                for: .syncDelayed,
                surface: .territory,
                fallbackMessage: entry.snapshot.message
            )
        case .memberReady, .guestLocked, .emptyData:
            return nil
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
                .lineLimit(layoutBudget.detailLineLimit)
        }
    }

    private var mediumMetricContent: some View {
        let summary = entry.snapshot.summary ?? .zero
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("영역 현황")
                    .font(.headline)
                Text(summary.goalContext?.contextLabel ?? "앱에서 목표 기준을 다시 동기화해주세요.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(layoutBudget.detailLineLimit)
            }

            goalSummarySection(summary.goalContext)

            HStack(spacing: 8) {
                metricTile(title: "오늘", value: summary.todayTileCount, tint: .green)
                metricTile(title: "주간", value: summary.weeklyTileCount, tint: .blue)
                metricTile(title: "방어 예정", value: summary.defenseScheduledTileCount, tint: .orange)
            }
        }
    }

    private var mediumMetricCompactContent: some View {
        let summary = entry.snapshot.summary ?? .zero
        return VStack(alignment: .leading, spacing: 6) {
            Text("영역 현황")
                .font(.headline)
            Text(summary.goalContext?.contextLabel ?? "앱에서 목표 기준을 다시 동기화해 주세요.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 8) {
                metricTile(title: "오늘", value: summary.todayTileCount, tint: .green)
                metricTile(title: "주간", value: summary.weeklyTileCount, tint: .blue)
            }
            Text(compactGoalSummaryText(summary.goalContext))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(layoutBudget.detailLineLimit)
        }
    }

    /// 중형 위젯에서 다음 목표/남은 면적 요약 블록을 렌더링합니다.
    /// - Parameter goalContext: 선택 반려견 기준으로 계산된 목표 문맥 스냅샷입니다.
    /// - Returns: 목표 확정 상태와 fallback 상태를 공통 카드로 표현한 요약 뷰입니다.
    private func goalSummarySection(_ goalContext: TerritoryWidgetGoalContextSnapshot?) -> some View {
        let resolvedStatus = goalContext?.status ?? .unavailable
        let accentColor: Color
        let titleText: String
        let detailText: String
        let captionText: String
        let progressRatio: Double?

        switch resolvedStatus {
        case .ready:
            accentColor = .orange
            titleText = goalContext?.nextGoalName ?? "다음 목표"
            let remainingText = layoutBudget.areaText(goalContext?.remainingAreaM2 ?? 0)
            let goalAreaText = layoutBudget.areaText(goalContext?.nextGoalAreaM2 ?? 0)
            detailText = "남은 \(remainingText) · 목표 \(goalAreaText)"
            captionText = goalContext?.message ?? "다음 산책 목표를 계산했어요."
            progressRatio = goalContext?.progressRatio
        case .completed:
            accentColor = .green
            titleText = "준비된 목표 완료"
            detailText = "현재 비교 구역 기준을 모두 달성했어요."
            captionText = goalContext?.message ?? "앱에서 새 비교 구역을 확인해보세요."
            progressRatio = 1.0
        case .emptyData:
            accentColor = .blue
            titleText = "다음 목표 준비 중"
            detailText = "첫 산책 후 남은 면적을 계산해드릴게요."
            captionText = goalContext?.message ?? "기록이 쌓이면 바로 목표를 보여드릴게요."
            progressRatio = nil
        case .unavailable:
            accentColor = .gray
            titleText = "목표 동기화 필요"
            detailText = "앱을 열어 비교 구역을 다시 불러와주세요."
            captionText = goalContext?.message ?? "오프라인이 길어지면 목표 계산이 늦어질 수 있어요."
            progressRatio = nil
        }

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("다음 목표")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(titleText)
                        .font(.headline)
                        .lineLimit(layoutBudget.headlineLineLimit)
                    Text(detailText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(layoutBudget.detailLineLimit)
                }
                Spacer(minLength: 8)
                if let progressRatio {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("진행")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(WidgetFormatting.formattedPercent(progressRatio))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(accentColor)
                            .monospacedDigit()
                    }
                }
            }

            if let progressRatio {
                ProgressView(value: progressRatio)
                    .tint(accentColor)
                    .scaleEffect(x: 1, y: 1.2, anchor: .center)
            }

            Text(captionText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(layoutBudget.detailLineLimit)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(accentColor.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 중형 위젯에서 개별 지표 타일을 렌더링합니다.
    /// - Parameters:
    ///   - title: 타일 상단에 표시할 지표 이름입니다.
    ///   - value: 강조 표시할 지표 값입니다.
    ///   - tint: 지표 강조 색상입니다.
    /// - Returns: 타이틀/숫자/배경 강조가 적용된 지표 타일 뷰입니다.
    private func metricTile(title: String, value: Int, tint: Color) -> some View {
        WidgetMetricTileView(
            title: title,
            value: "\(value)",
            tint: tint,
            budget: layoutBudget
        )
    }

    /// 지연/오프라인 상태에서 사용할 footer 안내와 CTA를 family 공통 예산으로 렌더링합니다.
    /// - Parameters:
    ///   - guide: 상태 taxonomy에서 계산한 안내/CTA 정보입니다.
    ///   - tint: CTA 강조 색상입니다.
    /// - Returns: 보조 설명과 CTA가 묶인 footer 뷰입니다.
    private func stateGuideFooterView(
        _ guide: WidgetStatePresentationContent,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(guide.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(layoutBudget.detailLineLimit)
            WidgetStateCTAView(
                cta: guide.cta,
                budget: layoutBudget,
                tint: tint
            )
        }
    }

    /// 중형 위젯 compact fallback에서 목표 요약을 한 줄 설명으로 압축합니다.
    /// - Parameter goalContext: 선택 반려견 기준으로 계산된 목표 문맥 스냅샷입니다.
    /// - Returns: 세로 예산이 부족할 때 사용할 축약 목표 요약 문자열입니다.
    private func compactGoalSummaryText(_ goalContext: TerritoryWidgetGoalContextSnapshot?) -> String {
        guard let goalContext else {
            return "앱에서 목표 기준을 다시 확인해 주세요."
        }
        switch goalContext.status {
        case .ready:
            let remainingText = layoutBudget.areaText(goalContext.remainingAreaM2)
            return "\(goalContext.nextGoalName)까지 \(remainingText) 남았어요."
        case .completed:
            return "현재 비교 구역 기준을 모두 달성했어요."
        case .emptyData:
            return "첫 산책이 기록되면 다음 목표를 바로 계산해 드릴게요."
        case .unavailable:
            return goalContext.message ?? "목표 기준을 다시 불러와 주세요."
        }
    }

    private var updatedAtText: String {
        if let refreshedAt = entry.snapshot.summary?.refreshedAt {
            return "업데이트 \(WidgetFormatting.formattedTime(timestamp: refreshedAt))"
        }
        return "업데이트 -"
    }

    private var statusBadgeText: String {
        if let guide = nonReadyStateGuide {
            return guide.badgeTitle
        }
        switch entry.snapshot.status {
        case .memberReady:
            return "실시간"
        case .offlineCached, .syncDelayed, .guestLocked, .emptyData:
            return "실시간"
        }
    }

    private var statusBadgeColor: Color {
        if let guide = nonReadyStateGuide {
            return guide.badgeColor
        }
        switch entry.snapshot.status {
        case .memberReady:
            return .green.opacity(0.2)
        case .offlineCached, .syncDelayed, .guestLocked, .emptyData:
            return .green.opacity(0.2)
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
        .description("오늘/주간 점령 지표와 다음 목표를 빠르게 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
