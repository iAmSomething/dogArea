import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
@available(iOSApplicationExtension 16.1, *)
private struct WalkLiveActivityView: View {
    let context: ActivityViewContext<WalkLiveActivityAttributes>

    private var endRouteURL: URL? {
        WalkWidgetActionRoute(
            kind: .endWalk,
            actionId: "live.end.\(Int(Date().timeIntervalSince1970))",
            source: "live_activity",
            contextId: nil
        ).makeURL()
    }

    private var openRouteURL: URL? {
        WalkWidgetActionRoute(
            kind: .startWalk,
            actionId: "live.open.\(Int(Date().timeIntervalSince1970))",
            source: "live_activity",
            contextId: nil
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
                Label(WidgetFormatting.formattedElapsed(context.state.elapsedSeconds), systemImage: "clock")
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
                    Text(WidgetFormatting.formattedElapsed(context.state.elapsedSeconds))
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
