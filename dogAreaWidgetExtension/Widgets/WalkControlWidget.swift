import WidgetKit
import SwiftUI

struct WalkControlTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: WalkWidgetSnapshot
}

private enum WalkControlElapsedDisplayMode {
    case liveTimer(referenceDate: Date)
    case frozen(text: String)
}

private struct WalkControlElapsedTextView: View {
    let displayMode: WalkControlElapsedDisplayMode

    var body: some View {
        switch displayMode {
        case .liveTimer(let referenceDate):
            Text(referenceDate, style: .timer)
                .monospacedDigit()
        case .frozen(let text):
            Text(text)
                .monospacedDigit()
        }
    }
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
        let snapshot = snapshotStore.load()
        let entry = WalkControlTimelineEntry(date: now, snapshot: snapshot)
        let next = nextRefreshDate(for: snapshot, from: now)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    /// 현재 위젯 스냅샷 상태에 맞는 다음 타임라인 갱신 시각을 계산합니다.
    /// - Parameters:
    ///   - snapshot: 위젯에 렌더링할 현재 산책 스냅샷입니다.
    ///   - now: 타임라인 계산 기준 시각입니다.
    /// - Returns: 시스템에 요청할 다음 타임라인 갱신 시각입니다.
    private func nextRefreshDate(for snapshot: WalkWidgetSnapshot, from now: Date) -> Date {
        if snapshot.isWalking {
            return now.addingTimeInterval(60)
        }
        if snapshot.normalizedActionState?.phase == .pending {
            return now.addingTimeInterval(30)
        }
        if snapshot.normalizedActionState?.phase == .requiresAppOpen {
            return now.addingTimeInterval(120)
        }
        return now.addingTimeInterval(15 * 60)
    }
}

struct WalkControlWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: WalkControlTimelineEntry

    var body: some View {
        Group {
            if family == .systemSmall {
                smallLayout
            } else {
                mediumLayout
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var activeActionState: WalkWidgetActionState? {
        entry.snapshot.normalizedActionState
    }

    private var petContext: WalkWidgetPetContext {
        entry.snapshot.normalizedPetContext
    }

    private var effectiveStatusMessage: String? {
        activeActionState?.message ?? entry.snapshot.statusMessage
    }

    private var elapsedDisplayMode: WalkControlElapsedDisplayMode {
        if entry.snapshot.isWalking {
            return .liveTimer(referenceDate: entry.snapshot.timerReferenceDate)
        }
        return .frozen(text: WidgetFormatting.formattedElapsed(entry.snapshot.elapsedSeconds))
    }

    private var preferredActionKind: WalkWidgetActionKind {
        activeActionState?.kind ?? (entry.snapshot.isWalking ? .endWalk : .startWalk)
    }

    private var walkStateTitle: String {
        entry.snapshot.isWalking ? "산책 중" : "산책 대기"
    }

    private var compactSupportText: String? {
        let message = effectiveStatusMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let message, message.isEmpty == false {
            return message
        }
        let detail = petContext.detailText.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? nil : detail
    }

    private var compactActionBlockedTitle: String {
        family == .systemSmall ? "반려견 확인" : "앱에서 반려견 확인"
    }

    private var actionBadgeTitle: String {
        guard let activeActionState else { return "" }
        switch activeActionState.phase {
        case .pending:
            return "처리 중"
        case .requiresAppOpen:
            return "앱 확인"
        case .succeeded:
            return "완료"
        case .failed:
            return "다시 확인"
        }
    }

    private var actionBadgeColor: Color {
        guard let activeActionState else { return .secondary.opacity(0.16) }
        switch activeActionState.phase {
        case .pending:
            return .blue.opacity(0.18)
        case .requiresAppOpen:
            return .orange.opacity(0.20)
        case .succeeded:
            return .green.opacity(0.20)
        case .failed:
            return .red.opacity(0.18)
        }
    }

    private var petContextBadgeColor: Color {
        switch petContext.source {
        case .selectedPet:
            return .green.opacity(0.18)
        case .fallbackActivePet:
            return .orange.opacity(0.18)
        case .walkingLocked:
            return .blue.opacity(0.18)
        case .noActivePet:
            return .red.opacity(0.18)
        }
    }

    /// 소형 위젯 레이아웃을 렌더링합니다.
    /// - Returns: 핵심 상태와 CTA 하나만 남긴 compact 위젯 본문입니다.
    @ViewBuilder
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            badgeRow

            Text(walkStateTitle)
                .font(.headline)
                .lineLimit(1)

            Text(petContext.petName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                WalkControlElapsedTextView(displayMode: elapsedDisplayMode)
                    .font(.system(.caption, design: .rounded).monospacedDigit().weight(.semibold))
                Spacer(minLength: 0)
            }

            if let compactSupportText {
                Text(compactSupportText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            primaryActionButton(compact: true)
        }
    }

    /// 중형 위젯 레이아웃을 렌더링합니다.
    /// - Returns: 반려견 문맥과 상태 메시지를 함께 담는 확장 위젯 본문입니다.
    @ViewBuilder
    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            badgeRow

            VStack(alignment: .leading, spacing: 2) {
                Text(walkStateTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(petContext.petName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(petContext.detailText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                WalkControlElapsedTextView(displayMode: elapsedDisplayMode)
                    .font(.system(.body, design: .rounded).monospacedDigit())
                Spacer(minLength: 0)
                Text(WidgetFormatting.formattedTime(timestamp: entry.snapshot.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let statusMessage = effectiveStatusMessage,
               statusMessage.isEmpty == false {
                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 2)

            primaryActionButton(compact: false)
        }
    }

    /// 상태 배지와 pending indicator를 포함한 상단 행을 렌더링합니다.
    /// - Returns: 현재 상태에 맞는 배지와 보조 인디케이터를 담은 상단 행입니다.
    @ViewBuilder
    private var badgeRow: some View {
        HStack(spacing: 6) {
            if let activeActionState {
                WidgetStatusBadge(title: actionBadgeTitle, color: actionBadgeColor)
                if activeActionState.phase == .pending {
                    ProgressView()
                        .controlSize(.small)
                }
            } else {
                WidgetStatusBadge(title: petContext.badgeTitle, color: petContextBadgeColor)
            }
        }
    }

    /// 현재 family에 맞는 주 CTA를 렌더링합니다.
    /// - Parameter compact: 소형 위젯용 compact CTA 스타일 적용 여부입니다.
    /// - Returns: 현재 상태에서 가장 중요한 액션을 수행하는 CTA 뷰입니다.
    @ViewBuilder
    private func primaryActionButton(compact: Bool) -> some View {
        if entry.snapshot.isWalking == false,
          petContext.blocksInlineStart {
            Button(intent: OpenWalkTabIntent()) {
                actionLabel(
                    title: compactActionBlockedTitle,
                    systemImage: "pawprint",
                    compact: compact
                )
            }
            .buttonStyle(.bordered)
        } else if let activeActionState,
           activeActionState.phase == .pending {
            pendingActionSurface(compact: compact)
        } else if let activeActionState,
                  activeActionState.followUp == .openApp {
            Button(intent: OpenWalkTabIntent()) {
                actionLabel(
                    title: "앱에서 확인",
                    systemImage: "arrow.up.right.square",
                    compact: compact
                )
            }
            .buttonStyle(.bordered)
        } else if let activeActionState,
                  activeActionState.phase == .failed,
                  activeActionState.followUp == .retry {
            retryActionButton(compact: compact)
        } else {
            defaultActionButton(compact: compact)
        }
    }

    /// 재시도 상태의 CTA를 렌더링합니다.
    /// - Parameter compact: 소형 위젯용 compact CTA 스타일 적용 여부입니다.
    /// - Returns: 실패 후 재시도 또는 앱 확인을 수행하는 CTA 뷰입니다.
    @ViewBuilder
    private func retryActionButton(compact: Bool) -> some View {
        switch preferredActionKind {
        case .startWalk:
            Button(intent: StartWalkIntent()) {
                actionLabel(
                    title: "다시 시도",
                    systemImage: "arrow.clockwise",
                    compact: compact
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        case .endWalk:
            Button(intent: EndWalkIntent()) {
                actionLabel(
                    title: "다시 시도",
                    systemImage: "arrow.clockwise",
                    compact: compact
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        case .openWalkTab, .claimQuestReward, .openQuestDetail, .openQuestRecovery, .openRivalTab:
            Button(intent: OpenWalkTabIntent()) {
                actionLabel(
                    title: "앱에서 확인",
                    systemImage: "arrow.up.right.square",
                    compact: compact
                )
            }
            .buttonStyle(.bordered)
        }
    }

    /// 기본 산책 시작/종료 CTA를 렌더링합니다.
    /// - Parameter compact: 소형 위젯용 compact CTA 스타일 적용 여부입니다.
    /// - Returns: 산책 시작 또는 종료를 수행하는 CTA 뷰입니다.
    @ViewBuilder
    private func defaultActionButton(compact: Bool) -> some View {
        if entry.snapshot.isWalking {
            Button(intent: EndWalkIntent()) {
                actionLabel(
                    title: "산책 종료",
                    systemImage: "stop.fill",
                    compact: compact
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        } else {
            Button(intent: StartWalkIntent()) {
                actionLabel(
                    title: "산책 시작",
                    systemImage: "play.fill",
                    compact: compact
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    /// family에 맞는 CTA 라벨 스타일을 생성합니다.
    /// - Parameters:
    ///   - title: 버튼 제목입니다.
    ///   - systemImage: 함께 노출할 SF Symbol 이름입니다.
    ///   - compact: 소형 위젯용 compact 스타일 적용 여부입니다.
    /// - Returns: 버튼 제목과 아이콘을 공통 규칙으로 렌더링한 라벨 뷰입니다.
    private func actionLabel(title: String, systemImage: String, compact: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .font(compact ? .caption.weight(.semibold) : .callout.weight(.semibold))
            .lineLimit(compact ? 1 : 2)
            .frame(maxWidth: .infinity, minHeight: compact ? 34 : 40)
    }

    /// pending 상태에서 사용하는 비활성 CTA surface를 생성합니다.
    /// - Parameter compact: 소형 위젯용 compact 스타일 적용 여부입니다.
    /// - Returns: 위젯 경계를 넘지 않는 고정 높이 pending surface입니다.
    private func pendingActionSurface(compact: Bool) -> some View {
        Label("처리 중", systemImage: "hourglass")
            .font(compact ? .caption.weight(.semibold) : .callout.weight(.semibold))
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: compact ? 34 : 40)
            .foregroundStyle(.secondary)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct WalkControlWidget: Widget {
    private let kind = WalkWidgetBridgeContract.walkWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WalkControlTimelineProvider()) { entry in
            WalkControlWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("산책 시작/종료")
        .description("홈/잠금 화면에서 산책 시작과 종료를 빠르게 실행합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    WalkControlWidget()
} timeline: {
    WalkControlTimelineEntry(
        date: Date(),
        snapshot: .init(
            isWalking: true,
            startedAt: Date().addingTimeInterval(-824).timeIntervalSince1970,
            elapsedSeconds: 824,
            petName: "나무",
            petContext: .init(
                petId: "preview-pet",
                petName: "나무",
                source: .walkingLocked,
                startPolicy: .selectedPetImmediate,
                fallbackReason: nil
            ),
            status: .ready,
            statusMessage: nil,
            actionState: nil,
            updatedAt: Date().timeIntervalSince1970
        )
    )
}

#Preview(as: .systemMedium) {
    WalkControlWidget()
} timeline: {
    WalkControlTimelineEntry(
        date: Date(),
        snapshot: .init(
            isWalking: false,
            startedAt: 0,
            elapsedSeconds: 0,
            petName: "초코",
            petContext: .init(
                petId: "preview-pet-medium",
                petName: "초코",
                source: .selectedPet,
                startPolicy: .selectedPetImmediate,
                fallbackReason: nil
            ),
            status: .ready,
            statusMessage: "앱을 열지 않아도 바로 산책을 시작할 수 있어요.",
            actionState: .init(
                kind: .startWalk,
                phase: .requiresAppOpen,
                followUp: .openApp,
                message: "앱에서 마지막 권한 상태를 확인해 주세요.",
                updatedAt: Date().addingTimeInterval(-120).timeIntervalSince1970,
                expiresAt: Date().addingTimeInterval(300).timeIntervalSince1970
            ),
            updatedAt: Date().timeIntervalSince1970
        )
    )
}
