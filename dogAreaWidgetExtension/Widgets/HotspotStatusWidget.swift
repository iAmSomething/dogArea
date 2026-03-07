import AppIntents
import WidgetKit
import SwiftUI

enum HotspotWidgetRadiusPresetOption: String, AppEnum {
    case nearby = "nearby"
    case balanced = "balanced"
    case broad = "broad"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "핫스팟 반경")
    }

    static var caseDisplayRepresentations: [HotspotWidgetRadiusPresetOption: DisplayRepresentation] {
        [
            .nearby: DisplayRepresentation(
                title: "0.5km",
                subtitle: "가장 가까운 흐름"
            ),
            .balanced: DisplayRepresentation(
                title: "1km",
                subtitle: "기본 주변 범위"
            ),
            .broad: DisplayRepresentation(
                title: "3km",
                subtitle: "넓은 범위 추세"
            )
        ]
    }

    /// 위젯 설정 옵션을 공유 스냅샷에서 사용하는 반경 preset으로 변환합니다.
    /// - Returns: 앱과 위젯이 공통으로 사용하는 반경 preset입니다.
    var preset: HotspotWidgetRadiusPreset {
        switch self {
        case .nearby:
            return .nearby
        case .balanced:
            return .balanced
        case .broad:
            return .broad
        }
    }
}

struct HotspotWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "핫스팟 반경"
    static var description = IntentDescription("위젯에서 확인할 익명 핫스팟 범위를 고릅니다.")

    @Parameter(title: "반경")
    var radiusPreset: HotspotWidgetRadiusPresetOption?

    /// 위젯 구성 인텐트의 기본 반경 preset을 `balanced`로 초기화합니다.
    init() {
        self.radiusPreset = .balanced
    }

    static var parameterSummary: some ParameterSummary {
        Summary("반경 \(\.$radiusPreset)")
    }
}

struct HotspotStatusTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: HotspotWidgetSnapshot
}

struct HotspotStatusTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = HotspotStatusTimelineEntry
    typealias Intent = HotspotWidgetConfigurationIntent

    private let snapshotStore: HotspotWidgetSnapshotStoring

    /// 익명 핫스팟 위젯 타임라인 제공자를 생성합니다.
    /// - Parameter snapshotStore: 앱과 공유하는 핫스팟 스냅샷 저장소입니다.
    init(snapshotStore: HotspotWidgetSnapshotStoring = DefaultHotspotWidgetSnapshotStore.shared) {
        self.snapshotStore = snapshotStore
    }

    /// 위젯 갤러리 플레이스홀더 엔트리를 반환합니다.
    /// - Parameter context: 위젯 미리보기 컨텍스트입니다.
    /// - Returns: 기본 반경 preset을 포함한 플레이스홀더 엔트리입니다.
    func placeholder(in context: Context) -> HotspotStatusTimelineEntry {
        .init(date: Date(), snapshot: .initial(radiusPreset: .balanced))
    }

    /// 시스템 스냅샷 요청에 선택한 반경 preset 스냅샷을 전달합니다.
    /// - Parameters:
    ///   - configuration: 사용자가 선택한 핫스팟 반경 설정입니다.
    ///   - context: 스냅샷 요청 컨텍스트입니다.
    /// - Returns: 선택 반경 기준 핫스팟 스냅샷을 포함한 엔트리입니다.
    func snapshot(
        for configuration: HotspotWidgetConfigurationIntent,
        in context: Context
    ) async -> HotspotStatusTimelineEntry {
        .init(
            date: Date(),
            snapshot: snapshotStore.load(radiusPreset: configuration.radiusPreset?.preset ?? .balanced)
        )
    }

    /// 현재 공유 저장소 기준 타임라인을 생성합니다.
    /// - Parameters:
    ///   - configuration: 사용자가 선택한 핫스팟 반경 설정입니다.
    ///   - context: 타임라인 생성 컨텍스트입니다.
    /// - Returns: 선택 반경 기준 스냅샷과 다음 갱신 시점을 포함한 타임라인입니다.
    func timeline(
        for configuration: HotspotWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HotspotStatusTimelineEntry> {
        let now = Date()
        let entry = HotspotStatusTimelineEntry(
            date: now,
            snapshot: snapshotStore.load(radiusPreset: configuration.radiusPreset?.preset ?? .balanced)
        )
        return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(10 * 60)))
    }
}

struct HotspotStatusWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HotspotStatusTimelineEntry

    var body: some View {
        Group {
            switch entry.snapshot.status {
            case .guestLocked:
                guestContent
            case .emptyData:
                emptyContent
            case .memberReady, .privacyGuarded, .offlineCached, .syncDelayed:
                dataContent
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(routeURL)
    }

    private var currentPreset: HotspotWidgetRadiusPreset {
        entry.snapshot.summary?.radiusPreset ?? entry.snapshot.radiusPreset
    }

    private var routeURL: URL? {
        HotspotWidgetDeepLinkRoute(
            destination: .rivalDetail,
            source: "hotspot_widget",
            status: entry.snapshot.status,
            radiusPreset: currentPreset
        ).makeURL()
    }

    private var guestContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                WidgetStatusBadge(title: "비회원", color: .orange.opacity(0.2))
                Spacer(minLength: 0)
                presetBadge(currentPreset)
            }
            Text("익명 핫스팟")
                .font(.headline)
            Text("\(currentPreset.shortLabel) 기준으로 지역 트렌드 단계를 확인할 수 있어요. 로그인 후 활성화됩니다.")
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
            HStack(alignment: .top, spacing: 8) {
                WidgetStatusBadge(title: "신호 부족", color: .blue.opacity(0.18))
                Spacer(minLength: 0)
                presetBadge(currentPreset)
            }
            Text("주변 익명 신호를 수집 중입니다")
                .font(.headline)
                .lineLimit(2)
            Text(currentPreset.widgetSummaryDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(entry.snapshot.message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 2)
            Text(updatedAtText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var dataContent: some View {
        let summary = entry.snapshot.summary ?? .zero(radiusPreset: entry.snapshot.radiusPreset)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                WidgetStatusBadge(title: signalTitle(summary.signalLevel), color: signalColor(summary.signalLevel))
                Spacer(minLength: 0)
                presetBadge(summary.radiusPreset)
            }

            if family == .systemSmall {
                smallBody(summary: summary)
            } else {
                mediumBody(summary: summary)
            }

            if entry.snapshot.status != .memberReady {
                Text(entry.snapshot.message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    /// 반경 preset을 간단한 배지 형태로 렌더링합니다.
    /// - Parameter preset: 위젯에 표시할 핫스팟 반경 preset입니다.
    /// - Returns: 현재 반경 문맥을 보여주는 배지 뷰입니다.
    private func presetBadge(_ preset: HotspotWidgetRadiusPreset) -> some View {
        Text(preset.shortLabel)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
    }

    /// 소형 위젯 본문을 렌더링합니다.
    /// - Parameter summary: 익명 핫스팟 요약 스냅샷입니다.
    /// - Returns: 반경 문맥과 활성도 단계 정보를 담은 소형 본문 뷰입니다.
    private func smallBody(summary: HotspotWidgetSummarySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("활성도 \(signalTitle(summary.signalLevel))")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(1)
            Text(summary.radiusPreset.widgetSummaryTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(signalDistributionSummary(summary))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(policyFootnote(summary))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    /// 중형 위젯 본문을 렌더링합니다.
    /// - Parameter summary: 익명 핫스팟 요약 스냅샷입니다.
    /// - Returns: 반경별 유지 정보와 지연 주의 문구를 담은 중형 본문 뷰입니다.
    private func mediumBody(summary: HotspotWidgetSummarySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("익명 핫스팟 단계")
                .font(.headline)
            Text(summary.radiusPreset.widgetSummaryDetail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 8) {
                stageChip(title: "높음", isActive: summary.highCellCount > 0, tint: .red)
                stageChip(title: "보통", isActive: summary.mediumCellCount > 0, tint: .orange)
                stageChip(title: "낮음", isActive: summary.lowCellCount > 0, tint: .green)
            }
            Text(signalDistributionSummary(summary))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if let stalePriority = summary.radiusPreset.stalePriorityDescription {
                Text(stalePriority)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(policyFootnote(summary))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    /// 단계 활성 여부를 표시하는 캡슐 배지를 렌더링합니다.
    /// - Parameters:
    ///   - title: 배지에 표시할 단계 텍스트입니다.
    ///   - isActive: 해당 단계 신호가 감지되었는지 여부입니다.
    ///   - tint: 활성 상태일 때 사용할 강조 색상입니다.
    /// - Returns: 단계 상태를 나타내는 캡슐 배지 뷰입니다.
    private func stageChip(title: String, isActive: Bool, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isActive ? tint : .secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background((isActive ? tint.opacity(0.18) : Color.secondary.opacity(0.12)))
            .clipShape(Capsule())
            .accessibilityLabel(isActive ? "\(title) 단계 감지됨" : "\(title) 단계 없음")
    }

    /// 익명 단계 분포를 숫자 없이 요약 문구로 변환합니다.
    /// - Parameter summary: 익명 핫스팟 요약 스냅샷입니다.
    /// - Returns: 우세 단계 중심의 분포 요약 문자열입니다.
    private func signalDistributionSummary(_ summary: HotspotWidgetSummarySnapshot) -> String {
        switch dominantSignalLevel(summary) {
        case .high:
            return "\(summary.radiusPreset.shortLabel) 기준으로는 높음 단계 신호가 상대적으로 우세해요."
        case .medium:
            return "\(summary.radiusPreset.shortLabel) 기준으로는 보통 단계 신호가 가장 많이 관측돼요."
        case .low:
            return "\(summary.radiusPreset.shortLabel) 기준으로는 낮음 단계 신호가 중심이에요."
        case .none:
            return "아직 뚜렷한 단계 신호가 없어요."
        }
    }

    /// 단계별 집계를 바탕으로 우세 신호 단계를 계산합니다.
    /// - Parameter summary: 익명 핫스팟 요약 스냅샷입니다.
    /// - Returns: 우세한 익명 신호 단계입니다.
    private func dominantSignalLevel(_ summary: HotspotWidgetSummarySnapshot) -> HotspotWidgetSignalLevel {
        let high = summary.highCellCount
        let medium = summary.mediumCellCount
        let low = summary.lowCellCount

        if high == 0, medium == 0, low == 0 {
            return .none
        }
        if high >= medium, high >= low {
            return .high
        }
        if medium >= high, medium >= low {
            return .medium
        }
        return .low
    }

    /// 활성도 레벨을 사용자 표시 문자열로 변환합니다.
    /// - Parameter level: 익명 핫스팟 신호 레벨입니다.
    /// - Returns: 위젯에 표시할 한글 레벨 텍스트입니다.
    private func signalTitle(_ level: HotspotWidgetSignalLevel) -> String {
        switch level {
        case .high:
            return "높음"
        case .medium:
            return "보통"
        case .low:
            return "낮음"
        case .none:
            return "없음"
        }
    }

    /// 활성도 레벨에 대응하는 배지 배경색을 반환합니다.
    /// - Parameter level: 익명 핫스팟 신호 레벨입니다.
    /// - Returns: 배지 렌더링에 사용할 배경 색상입니다.
    private func signalColor(_ level: HotspotWidgetSignalLevel) -> Color {
        switch level {
        case .high:
            return .red.opacity(0.20)
        case .medium:
            return .orange.opacity(0.20)
        case .low:
            return .green.opacity(0.20)
        case .none:
            return .blue.opacity(0.16)
        }
    }

    /// 프라이버시 가드 상태를 설명하는 보조 문구를 생성합니다.
    /// - Parameter summary: 익명 핫스팟 요약 스냅샷입니다.
    /// - Returns: 반경 문맥과 지연/억제 정책을 설명하는 문자열입니다.
    private func policyFootnote(_ summary: HotspotWidgetSummarySnapshot) -> String {
        switch summary.suppressionReason {
        case "k_anon":
            return "k-익명 정책으로 백분위 단계만 제공됩니다."
        case "sensitive_mask":
            return "민감 지역은 마스킹되어 상세 신호가 제한됩니다."
        default:
            break
        }
        if summary.privacyMode == "percentile_only" {
            return "좌표/개별 카운트 없이 백분위 단계만 제공합니다."
        }
        if summary.delayMinutes > 0 {
            return "정책 지연 \(summary.delayMinutes)분 적용 · 개인 좌표 비노출"
        }
        return "개인 좌표/정밀 카운트는 제공하지 않습니다."
    }

    private var updatedAtText: String {
        if let refreshedAt = entry.snapshot.summary?.refreshedAt {
            return "업데이트 \(WidgetFormatting.formattedTime(timestamp: refreshedAt))"
        }
        return "업데이트 -"
    }
}

struct HotspotStatusWidget: Widget {
    private let kind = WalkWidgetBridgeContract.hotspotWidgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: HotspotWidgetConfigurationIntent.self,
            provider: HotspotStatusTimelineProvider()
        ) { entry in
            HotspotStatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("익명 핫스팟")
        .description("주변 익명 핫스팟 활성도 단계를 선택한 반경 기준으로 표시합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
