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
        if let actionRefreshDate = nextRefreshDateForActionState(
            snapshot.normalizedActionState,
            from: now
        ) {
            return actionRefreshDate
        }
        if snapshot.isWalking {
            return now.addingTimeInterval(60)
        }
        return now.addingTimeInterval(15 * 60)
    }

    /// 액션 오버레이 상태가 만료되거나 다음 단계로 전환될 시점에 맞는 타임라인 갱신 시각을 계산합니다.
    /// - Parameters:
    ///   - actionState: 현재 위젯에 표시 중인 액션 오버레이 상태입니다.
    ///   - now: 타임라인 계산 기준 시각입니다.
    /// - Returns: 액션 상태가 있으면 만료 직후 갱신 시각을, 없으면 `nil`을 반환합니다.
    private func nextRefreshDateForActionState(
        _ actionState: WalkWidgetActionState?,
        from now: Date
    ) -> Date? {
        guard let actionState else { return nil }

        if let expiresAt = actionState.expiresAt {
            let expiryRefresh = Date(
                timeIntervalSince1970: max(
                    now.addingTimeInterval(1).timeIntervalSince1970,
                    expiresAt + 0.5
                )
            )
            return expiryRefresh
        }

        switch actionState.phase {
        case .pending:
            return now.addingTimeInterval(20)
        case .requiresAppOpen, .failed:
            return now.addingTimeInterval(30)
        case .succeeded:
            return now.addingTimeInterval(12)
        }
    }
}

private enum WalkControlPresentationMode: Equatable {
    case walking
    case ready
    case noActivePet
    case pending(WalkWidgetActionKind)
    case requiresAppOpen(WalkWidgetActionKind)
    case failedRetry(WalkWidgetActionKind)
    case failedOpenApp(WalkWidgetActionKind)
}

private struct WalkControlPresentationContent {
    let headline: String
    let supportingLine: String?
    let detailLine: String?
    let showsElapsed: Bool
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

    private var layoutBudget: WidgetSurfaceLayoutBudget {
        .resolve(for: family)
    }

    private var petContext: WalkWidgetPetContext {
        entry.snapshot.normalizedPetContext
    }

    private var presentationMode: WalkControlPresentationMode {
        if let activeActionState {
            switch (activeActionState.phase, activeActionState.followUp) {
            case (.pending, _):
                return .pending(activeActionState.kind)
            case (.requiresAppOpen, _):
                return .requiresAppOpen(activeActionState.kind)
            case (.failed, .retry):
                return .failedRetry(activeActionState.kind)
            case (.failed, _):
                return .failedOpenApp(activeActionState.kind)
            case (.succeeded, _):
                break
            }
        }

        if entry.snapshot.isWalking {
            return .walking
        }

        if petContext.blocksInlineStart {
            return .noActivePet
        }

        return .ready
    }

    private var elapsedDisplayMode: WalkControlElapsedDisplayMode {
        if entry.snapshot.isWalking {
            return .liveTimer(referenceDate: entry.snapshot.timerReferenceDate)
        }
        return .frozen(text: layoutBudget.elapsedText(entry.snapshot.elapsedSeconds))
    }

    private var preferredActionKind: WalkWidgetActionKind {
        activeActionState?.kind ?? (entry.snapshot.isWalking ? .endWalk : .startWalk)
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

    private var badgeDescriptors: [WidgetBadgeDescriptor] {
        if activeActionState != nil {
            return [
                WidgetBadgeDescriptor(id: "action", title: actionBadgeTitle, color: actionBadgeColor)
            ]
        }

        return [
            WidgetBadgeDescriptor(id: "pet", title: petContext.badgeTitle, color: petContextBadgeColor)
        ]
    }

    /// `systemSmall` family의 worst-case 상태를 감안한 compact 카피를 계산합니다.
    /// - Returns: compact family에서 사용할 headline, 보조 줄, 세부 줄, 경과 시간 표시 여부입니다.
    private func makeCompactPresentation() -> WalkControlPresentationContent {
        switch presentationMode {
        case .walking:
            return .init(
                headline: "산책 중",
                supportingLine: petContext.petName,
                detailLine: nil,
                showsElapsed: true
            )
        case .ready:
            return .init(
                headline: "산책 준비",
                supportingLine: petContext.petName,
                detailLine: "바로 시작해요",
                showsElapsed: false
            )
        case .noActivePet:
            return .init(
                headline: "앱에서 확인",
                supportingLine: nil,
                detailLine: "반려견을 선택해요",
                showsElapsed: false
            )
        case .pending:
            return .init(
                headline: "처리 중",
                supportingLine: petContext.petName,
                detailLine: "앱이 열리면 이어져요",
                showsElapsed: false
            )
        case .requiresAppOpen:
            return .init(
                headline: "앱에서 확인",
                supportingLine: nil,
                detailLine: "앱에서 이어서 확인",
                showsElapsed: false
            )
        case .failedRetry:
            return .init(
                headline: "다시 시도",
                supportingLine: petContext.petName,
                detailLine: "한 번 더 시도해요",
                showsElapsed: false
            )
        case .failedOpenApp:
            return .init(
                headline: "앱에서 확인",
                supportingLine: nil,
                detailLine: "앱에서 이어서 확인",
                showsElapsed: false
            )
        }
    }

    /// `systemMedium` family의 canonical 카피를 계산합니다.
    /// - Returns: standard family에서 사용할 headline, 보조 줄, 세부 줄, 경과 시간 표시 여부입니다.
    private func makeStandardPresentation() -> WalkControlPresentationContent {
        switch presentationMode {
        case .walking:
            return .init(
                headline: "산책 중",
                supportingLine: petContext.petName,
                detailLine: "지금 산책 기록을 계속 반영하고 있어요.",
                showsElapsed: true
            )
        case .ready:
            return .init(
                headline: "산책 준비",
                supportingLine: petContext.petName,
                detailLine: "\(petContext.petName)와 바로 산책을 시작할 수 있어요.",
                showsElapsed: false
            )
        case .noActivePet:
            return .init(
                headline: "앱에서 반려견 확인",
                supportingLine: nil,
                detailLine: "활성 반려견이 없어 앱에서 먼저 확인이 필요해요.",
                showsElapsed: false
            )
        case .pending(let kind):
            return .init(
                headline: kind == .startWalk ? "산책 시작 준비" : "산책 종료 준비",
                supportingLine: petContext.petName,
                detailLine: "앱이 열리면 요청을 이어서 처리해요.",
                showsElapsed: false
            )
        case .requiresAppOpen(let kind):
            return .init(
                headline: kind == .startWalk ? "앱에서 시작 확인" : "앱에서 종료 확인",
                supportingLine: nil,
                detailLine: "권한 또는 현재 산책 상태를 앱에서 확인해 주세요.",
                showsElapsed: false
            )
        case .failedRetry(let kind):
            return .init(
                headline: kind == .startWalk ? "산책 시작 재시도" : "산책 종료 재시도",
                supportingLine: petContext.petName,
                detailLine: "요청이 끝나지 않았어요. 위젯에서 다시 시도할 수 있어요.",
                showsElapsed: false
            )
        case .failedOpenApp(let kind):
            return .init(
                headline: kind == .startWalk ? "앱에서 시작 확인" : "앱에서 종료 확인",
                supportingLine: nil,
                detailLine: "현재 상태 확인이 필요해 앱에서 이어서 처리해 주세요.",
                showsElapsed: false
            )
        }
    }

    /// 소형 위젯 레이아웃을 렌더링합니다.
    /// - Returns: 핵심 상태와 CTA 하나만 남긴 compact 위젯 본문입니다.
    @ViewBuilder
    private var smallLayout: some View {
        let presentation = makeCompactPresentation()
        WidgetSurfacePage(budget: layoutBudget) {
            EmptyView()
        } body: {
            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.headline)
                    .font(.headline)
                    .lineLimit(layoutBudget.headlineLineLimit)

                if let supportingLine = presentation.supportingLine {
                    Text(supportingLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }

                if presentation.showsElapsed {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        WalkControlElapsedTextView(displayMode: elapsedDisplayMode)
                            .font(.system(.caption, design: .rounded).monospacedDigit().weight(.semibold))
                        Spacer(minLength: 0)
                    }
                } else if let detailLine = presentation.detailLine {
                    Text(detailLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(layoutBudget.detailLineLimit)
                        .minimumScaleFactor(0.88)
                }
            }
        } footer: {
            primaryActionButton(compact: true)
        }
    }

    /// 중형 위젯 레이아웃을 렌더링합니다.
    /// - Returns: 반려견 문맥과 상태 메시지를 함께 담는 확장 위젯 본문입니다.
    @ViewBuilder
    private var mediumLayout: some View {
        WidgetSurfacePage(budget: layoutBudget) {
            badgeRow
        } body: {
            ViewThatFits(in: .vertical) {
                mediumPrimaryContent
                mediumCompactContent
            }
        } footer: {
            primaryActionButton(compact: false)
        }
    }

    private var mediumPrimaryContent: some View {
        let presentation = makeStandardPresentation()
        return VStack(alignment: .leading, spacing: layoutBudget.verticalSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.headline)
                    .font(.headline)
                    .lineLimit(layoutBudget.headlineLineLimit)
                if let supportingLine = presentation.supportingLine {
                    Text(supportingLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                }
            }

            if let detailLine = presentation.detailLine {
                Text(detailLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(layoutBudget.statusLineLimit)
            }

            if presentation.showsElapsed {
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
            }
        }
    }

    private var mediumCompactContent: some View {
        let presentation = makeStandardPresentation()
        return VStack(alignment: .leading, spacing: 6) {
            Text(presentation.headline)
                .font(.headline)
                .lineLimit(1)
            if let supportingLine = presentation.supportingLine {
                Text(supportingLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            if presentation.showsElapsed {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    WalkControlElapsedTextView(displayMode: elapsedDisplayMode)
                        .font(.system(.caption, design: .rounded).monospacedDigit().weight(.semibold))
                    Spacer(minLength: 0)
                }
            } else if let detailLine = presentation.detailLine {
                Text(detailLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
            }
        }
    }

    /// 상태 배지와 pending indicator를 포함한 상단 행을 렌더링합니다.
    /// - Returns: 현재 상태에 맞는 배지와 보조 인디케이터를 담은 상단 행입니다.
    @ViewBuilder
    private var badgeRow: some View {
        HStack(spacing: layoutBudget.badgeSpacing) {
            WidgetBadgeStripView(
                badges: badgeDescriptors,
                budget: layoutBudget
            )
            if let activeActionState,
               activeActionState.phase == .pending {
                ProgressView()
                    .controlSize(.small)
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
            .lineLimit(compact ? layoutBudget.ctaLineLimit : WidgetSurfaceLayoutBudget.standard.ctaLineLimit)
            .minimumScaleFactor(0.82)
            .frame(
                maxWidth: .infinity,
                minHeight: compact ? layoutBudget.ctaMinHeight : WidgetSurfaceLayoutBudget.standard.ctaMinHeight,
                maxHeight: compact ? layoutBudget.ctaMaxHeight : WidgetSurfaceLayoutBudget.standard.ctaMaxHeight
            )
    }

    /// pending 상태에서 사용하는 비활성 CTA surface를 생성합니다.
    /// - Parameter compact: 소형 위젯용 compact 스타일 적용 여부입니다.
    /// - Returns: 위젯 경계를 넘지 않는 고정 높이 pending surface입니다.
    private func pendingActionSurface(compact: Bool) -> some View {
        Label("처리 중", systemImage: "hourglass")
            .font(compact ? .caption.weight(.semibold) : .callout.weight(.semibold))
            .lineLimit(1)
            .frame(
                maxWidth: .infinity,
                minHeight: compact ? layoutBudget.ctaMinHeight : WidgetSurfaceLayoutBudget.standard.ctaMinHeight,
                maxHeight: compact ? layoutBudget.ctaMaxHeight : WidgetSurfaceLayoutBudget.standard.ctaMaxHeight
            )
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
