import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
@available(iOSApplicationExtension 16.1, *)
private struct WalkLiveActivityMetricTileView<Content: View>: View {
    let title: String
    let systemImage: String
    var tint: Color = .orange
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            content()
                .font(.system(.headline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

@available(iOSApplicationExtension 16.1, *)
private enum WalkLiveActivityElapsedDisplayMode {
    case liveTimer(referenceDate: Date)
    case frozen(fullText: String, compactText: String)
}

@available(iOSApplicationExtension 16.1, *)
private struct WalkLiveActivityPresentation {
    let petName: String
    let elapsedDisplayMode: WalkLiveActivityElapsedDisplayMode
    let areaText: String
    let compactAreaText: String
    let pointsText: String
    let progressHeadline: String
    let progressDetail: String
    let safetyTitle: String
    let safetyTint: Color
    let compactTrailingText: String
    let minimalSymbolName: String
}

@available(iOSApplicationExtension 16.1, *)
private struct WalkLiveActivityElapsedTextView: View {
    let presentation: WalkLiveActivityPresentation
    var compact: Bool = false

    var body: some View {
        switch presentation.elapsedDisplayMode {
        case let .liveTimer(referenceDate):
            Text(referenceDate, style: .timer)
                .minimumScaleFactor(compact ? 0.72 : 0.8)
        case let .frozen(fullText, compactText):
            Text(compact ? compactText : fullText)
                .minimumScaleFactor(compact ? 0.72 : 0.8)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private enum WalkLiveActivityPresentationGuide {
    /// Live Activity 상태를 expanded/compact/minimal 표면에서 공통으로 사용할 프레젠테이션 값으로 변환합니다.
    /// - Parameter state: ActivityKit이 전달한 현재 산책 상태입니다.
    /// - Returns: 시간, 영역, 안전 상태 우선순위가 반영된 프레젠테이션 값입니다.
    static func make(from state: WalkLiveActivityAttributes.ContentState) -> WalkLiveActivityPresentation {
        let safety = safetyPresentation(stage: state.autoEndStage)
        let summary = progressPresentation(
            stage: state.autoEndStage,
            pointCount: state.pointCount,
            capturedAreaM2: state.capturedAreaM2,
            statusMessage: state.statusMessage
        )
        let compactAreaText = WidgetFormatting.formattedCompactArea(state.capturedAreaM2)

        return .init(
            petName: state.petName,
            elapsedDisplayMode: elapsedDisplayMode(for: state),
            areaText: WidgetFormatting.formattedArea(state.capturedAreaM2),
            compactAreaText: compactAreaText,
            pointsText: "포인트 \(state.pointCount)",
            progressHeadline: summary.headline,
            progressDetail: summary.detail,
            safetyTitle: safety.title,
            safetyTint: safety.tint,
            compactTrailingText: compactTrailingText(for: state, compactAreaText: compactAreaText),
            minimalSymbolName: minimalSymbolName(for: state.autoEndStage),
        )
    }

    /// Live Activity의 경과 시간을 self-updating timer 또는 고정 문자열 중 하나로 정규화합니다.
    /// - Parameter state: ActivityKit이 전달한 현재 산책 상태입니다.
    /// - Returns: 진행 중 단계면 self-updating timer 기준 시각을, 종료 단계면 고정 시간을 반환합니다.
    private static func elapsedDisplayMode(
        for state: WalkLiveActivityAttributes.ContentState
    ) -> WalkLiveActivityElapsedDisplayMode {
        if state.autoEndStage == .ended {
            return .frozen(
                fullText: WidgetFormatting.formattedElapsed(state.elapsedSeconds),
                compactText: WidgetFormatting.formattedElapsedCompact(state.elapsedSeconds)
            )
        }

        let referenceTimestamp = max(0, state.updatedAt - Double(state.elapsedSeconds))
        return .liveTimer(referenceDate: Date(timeIntervalSince1970: referenceTimestamp))
    }

    /// 자동 종료 단계에 맞는 badge 제목과 강조 색을 계산합니다.
    /// - Parameter stage: 현재 산책 자동 종료 단계입니다.
    /// - Returns: 공통 badge 제목과 강조 색입니다.
    private static func safetyPresentation(
        stage: WalkLiveActivityAutoEndStage
    ) -> (title: String, tint: Color) {
        switch stage {
        case .active:
            return ("정상 기록 중", .green)
        case .restCandidate:
            return ("휴식 감지", .yellow)
        case .warning:
            return ("자동 종료 경고", .orange)
        case .autoEnding:
            return ("자동 종료 단계", .red)
        case .ended:
            return ("산책 종료", .secondary)
        }
    }

    /// 단계와 진행 수치를 함께 고려해 사용자에게 보여줄 headline/detail 쌍을 생성합니다.
    /// - Parameters:
    ///   - stage: 현재 산책 자동 종료 단계입니다.
    ///   - pointCount: 지금까지 기록된 포인트 수입니다.
    ///   - capturedAreaM2: 현재까지 확보된 영역입니다.
    ///   - statusMessage: 앱 런타임이 전달한 보조 상태 메시지입니다.
    /// - Returns: 잠금화면과 Dynamic Island가 함께 공유할 headline/detail 쌍입니다.
    private static func progressPresentation(
        stage: WalkLiveActivityAutoEndStage,
        pointCount: Int,
        capturedAreaM2: Double,
        statusMessage: String?
    ) -> (headline: String, detail: String) {
        let normalizedMessage = normalizedMessage(from: statusMessage)

        switch stage {
        case .ended:
            return (
                "산책이 종료되었어요",
                normalizedMessage ?? "앱에서 저장 결과와 산책 기록을 확인해 주세요."
            )
        case .autoEnding:
            return (
                "자동 종료 정리 중이에요",
                normalizedMessage ?? "움직임이 오래 없어 종료 단계에 들어갔어요. 앱에서 현재 세션을 확인해 주세요."
            )
        case .warning:
            return (
                "곧 자동 종료될 수 있어요",
                normalizedMessage ?? "움직임이 없으면 자동 종료 단계로 넘어가요. 다시 걸으면 바로 정상 기록으로 돌아갑니다."
            )
        case .restCandidate:
            return (
                "잠시 쉬는 중인지 확인하고 있어요",
                normalizedMessage ?? "다시 움직이면 정상 기록 중 상태로 바로 복귀합니다."
            )
        case .active:
            if capturedAreaM2 >= 1 {
                return (
                    "현재 확보 영역 \(WidgetFormatting.formattedArea(capturedAreaM2))",
                    "지금까지 포인트 \(pointCount)개를 기록하며 영역을 넓히고 있어요."
                )
            }
            if pointCount > 0 {
                return (
                    "첫 영역 기록을 쌓는 중이에요",
                    "포인트 \(pointCount)개가 기록됐고, 다음 마크가 쌓이면 영역 증가량이 바로 보입니다."
                )
            }
            return (
                "첫 포인트를 기다리고 있어요",
                "산책을 계속 이어가면 첫 기록이 생기는 즉시 영역 변화가 함께 보입니다."
            )
        }
    }

    /// 상태 메시지 문자열에서 사용자에게 노출 가능한 값을 추출합니다.
    /// - Parameter message: 런타임이 전달한 원본 상태 메시지입니다.
    /// - Returns: 공백만 남는 경우 `nil`, 아니면 trim된 메시지입니다.
    private static func normalizedMessage(from message: String?) -> String? {
        let trimmedMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedMessage, trimmedMessage.isEmpty == false {
            return trimmedMessage
        }
        return nil
    }

    /// compact trailing 영역에 노출할 우선 값을 계산합니다.
    /// - Parameters:
    ///   - state: ActivityKit 현재 상태입니다.
    ///   - compactAreaText: compact 폭에 맞춘 영역 증가량 문자열입니다.
    /// - Returns: compact trailing에 표시할 짧은 문자열입니다.
    private static func compactTrailingText(
        for state: WalkLiveActivityAttributes.ContentState,
        compactAreaText: String
    ) -> String {
        switch state.autoEndStage {
        case .warning:
            return "주의"
        case .autoEnding:
            return "확인"
        case .ended:
            return "완료"
        case .active, .restCandidate:
            if state.capturedAreaM2 >= 1 {
                return compactAreaText
            }
            return "\(state.pointCount)"
        }
    }

    /// minimal 표면에서 사용할 심볼 우선순위를 계산합니다.
    /// - Parameter stage: 자동 종료 단계 값입니다.
    /// - Returns: minimal 표면에 표시할 SF Symbol 이름입니다.
    private static func minimalSymbolName(for stage: WalkLiveActivityAutoEndStage) -> String {
        switch stage {
        case .active:
            return "figure.walk"
        case .restCandidate:
            return "pause.circle"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .autoEnding:
            return "stop.circle.fill"
        case .ended:
            return "checkmark.circle.fill"
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct WalkLiveActivityView: View {
    let context: ActivityViewContext<WalkLiveActivityAttributes>

    private var presentation: WalkLiveActivityPresentation {
        WalkLiveActivityPresentationGuide.make(from: context.state)
    }

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
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.petName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(presentation.progressHeadline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                WidgetStatusBadge(title: presentation.safetyTitle, color: presentation.safetyTint.opacity(0.18))
            }

            HStack(spacing: 10) {
                WalkLiveActivityMetricTileView(
                    title: "경과 시간",
                    systemImage: "clock",
                    tint: .blue
                ) {
                    WalkLiveActivityElapsedTextView(presentation: presentation)
                }
                WalkLiveActivityMetricTileView(
                    title: "현재 확보",
                    systemImage: "square.stack.3d.up.fill",
                    tint: .green
                ) {
                    Text(presentation.areaText)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Label(presentation.pointsText, systemImage: "mappin.and.ellipse")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(presentation.progressDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
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
            let presentation = WalkLiveActivityPresentationGuide.make(from: context.state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WalkLiveActivityMetricTileView(
                        title: "시간",
                        systemImage: "clock",
                        tint: .blue
                    ) {
                        WalkLiveActivityElapsedTextView(presentation: presentation, compact: true)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WalkLiveActivityMetricTileView(
                        title: "영역",
                        systemImage: "square.stack.3d.up.fill",
                        tint: .green
                    ) {
                        Text(presentation.compactAreaText)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(presentation.petName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(presentation.pointsText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        WidgetStatusBadge(
                            title: presentation.safetyTitle,
                            color: presentation.safetyTint.opacity(0.18)
                        )
                        Text(presentation.progressDetail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                }
            } compactLeading: {
                WalkLiveActivityElapsedTextView(presentation: presentation, compact: true)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
            } compactTrailing: {
                Text(presentation.compactTrailingText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(presentation.safetyTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } minimal: {
                Image(systemName: presentation.minimalSymbolName)
                    .foregroundStyle(presentation.safetyTint)
            }
            .keylineTint(presentation.safetyTint)
        }
    }
}
#endif
