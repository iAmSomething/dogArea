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
            Text(entry.snapshot.isWalking ? "산책 중" : "산책 대기")
                .font(.headline)
            Text(entry.snapshot.petName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text(formattedElapsed(entry.snapshot.elapsedSeconds))
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
    private func formattedElapsed(_ elapsedSeconds: Int) -> String {
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
