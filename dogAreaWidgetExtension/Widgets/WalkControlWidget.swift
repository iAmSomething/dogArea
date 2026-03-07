import WidgetKit
import SwiftUI

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
            if let activeActionState {
                HStack(spacing: 6) {
                    WidgetStatusBadge(title: actionBadgeTitle, color: actionBadgeColor)
                    if activeActionState.phase == .pending {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            } else {
                WidgetStatusBadge(title: petContext.badgeTitle, color: petContextBadgeColor)
            }

            Text(entry.snapshot.isWalking ? "산책 중" : "산책 대기")
                .font(.headline)
            Text(petContext.petName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(petContext.detailText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text(WidgetFormatting.formattedElapsed(entry.snapshot.elapsedSeconds))
                    .font(.system(.body, design: .rounded).monospacedDigit())
            }

            if let statusMessage = effectiveStatusMessage,
               statusMessage.isEmpty == false {
                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 2)

            primaryActionButton
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

    private var preferredActionKind: WalkWidgetActionKind {
        activeActionState?.kind ?? (entry.snapshot.isWalking ? .endWalk : .startWalk)
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

    @ViewBuilder
    private var primaryActionButton: some View {
        if entry.snapshot.isWalking == false,
          petContext.blocksInlineStart {
            Button(intent: OpenWalkTabIntent()) {
                Label("앱에서 반려견 확인", systemImage: "pawprint")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        } else if let activeActionState,
           activeActionState.phase == .pending {
            Label("처리 중", systemImage: "hourglass")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(.secondary)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else if let activeActionState,
                  activeActionState.followUp == .openApp {
            Button(intent: OpenWalkTabIntent()) {
                Label("앱에서 확인", systemImage: "arrow.up.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        } else if let activeActionState,
                  activeActionState.phase == .failed,
                  activeActionState.followUp == .retry {
            retryActionButton
        } else {
            defaultActionButton
        }
    }

    @ViewBuilder
    private var retryActionButton: some View {
        switch preferredActionKind {
        case .startWalk:
            Button(intent: StartWalkIntent()) {
                Label("다시 시도", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        case .endWalk:
            Button(intent: EndWalkIntent()) {
                Label("다시 시도", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        case .openWalkTab, .claimQuestReward, .openRivalTab:
            Button(intent: OpenWalkTabIntent()) {
                Label("앱에서 확인", systemImage: "arrow.up.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var defaultActionButton: some View {
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
