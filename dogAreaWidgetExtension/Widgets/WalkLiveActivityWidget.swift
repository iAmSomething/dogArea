import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
@available(iOSApplicationExtension 16.1, *)
private struct WalkLiveActivityMetricTileView: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = .orange

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
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
private struct WalkLiveActivityPresentation {
    let petName: String
    let elapsedText: String
    let compactElapsedText: String
    let areaText: String
    let compactAreaText: String
    let pointsText: String
    let progressHeadline: String
    let progressDetail: String
    let safetyTitle: String
    let safetyDetail: String
    let safetyTint: Color
    let compactTrailingText: String
    let minimalSymbolName: String
}

@available(iOSApplicationExtension 16.1, *)
private enum WalkLiveActivityPresentationGuide {
    /// Live Activity 상태를 expanded/compact/minimal 표면에서 공통으로 사용할 프레젠테이션 값으로 변환합니다.
    /// - Parameter state: ActivityKit이 전달한 현재 산책 상태입니다.
    /// - Returns: 시간, 영역, 안전 상태 우선순위가 반영된 프레젠테이션 값입니다.
    static func make(from state: WalkLiveActivityAttributes.ContentState) -> WalkLiveActivityPresentation {
        let safety = safetyPresentation(
            stage: state.autoEndStage,
            message: state.statusMessage
        )
        let compactAreaText = WidgetFormatting.formattedCompactArea(state.capturedAreaM2)
        let progressHeadline: String
        let progressDetail: String

        if state.capturedAreaM2 >= 1 {
            progressHeadline = "현재 확보 영역 \(WidgetFormatting.formattedArea(state.capturedAreaM2))"
            progressDetail = "지금까지 포인트 \(state.pointCount)개를 기록하며 영역을 넓히고 있어요."
        } else if state.pointCount > 0 {
            progressHeadline = "첫 영역 기록을 쌓는 중이에요"
            progressDetail = "포인트 \(state.pointCount)개가 기록됐고, 다음 마크가 쌓이면 영역 증가량이 바로 보입니다."
        } else {
            progressHeadline = "첫 포인트를 기다리고 있어요"
            progressDetail = "산책을 계속 이어가면 경과 시간 다음으로 영역 증가량을 우선 보여드릴게요."
        }

        return .init(
            petName: state.petName,
            elapsedText: WidgetFormatting.formattedElapsed(state.elapsedSeconds),
            compactElapsedText: WidgetFormatting.formattedElapsedCompact(state.elapsedSeconds),
            areaText: WidgetFormatting.formattedArea(state.capturedAreaM2),
            compactAreaText: compactAreaText,
            pointsText: "포인트 \(state.pointCount)",
            progressHeadline: progressHeadline,
            progressDetail: progressDetail,
            safetyTitle: safety.title,
            safetyDetail: safety.detail,
            safetyTint: safety.tint,
            compactTrailingText: compactTrailingText(for: state, compactAreaText: compactAreaText),
            minimalSymbolName: minimalSymbolName(for: state.autoEndStage),
        )
    }

    /// 자동 종료 단계와 상태 메시지를 compact/expanded 공통 안전 메시지로 정규화합니다.
    /// - Parameters:
    ///   - stage: 자동 종료 단계 값입니다.
    ///   - message: ViewModel이 전달한 현재 상태 메시지입니다.
    /// - Returns: 단계별 제목, 세부 문구, 강조 색을 포함한 안전 프레젠테이션 값입니다.
    private static func safetyPresentation(
        stage: WalkLiveActivityAutoEndStage,
        message: String?
    ) -> (title: String, detail: String, tint: Color) {
        let trimmedMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMessage = trimmedMessage?.isEmpty == false ? trimmedMessage : nil

        switch stage {
        case .active:
            return ("정상 기록 중", normalizedMessage ?? "자동 종료 위험 없이 현재 산책 가치가 정상적으로 쌓이고 있어요.", .green)
        case .restCandidate:
            return ("휴식 감지", normalizedMessage ?? "5분 무이동 상태예요. 다시 움직이면 휴식 단계가 바로 해제됩니다.", .yellow)
        case .warning:
            return ("자동 종료 경고", normalizedMessage ?? "12분 무이동 상태예요. 3분 뒤 자동 종료될 수 있습니다.", .orange)
        case .autoEnding:
            return ("자동 종료 단계", normalizedMessage ?? "15분 무이동 단계예요. 앱을 열어 종료/복구 상태를 확인해 주세요.", .red)
        case .ended:
            return ("산책 종료", normalizedMessage ?? "현재 세션은 종료 상태입니다.", .secondary)
        }
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
            return "종료"
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
                    value: presentation.elapsedText,
                    systemImage: "clock",
                    tint: .blue
                )
                WalkLiveActivityMetricTileView(
                    title: "현재 확보",
                    value: presentation.areaText,
                    systemImage: "square.stack.3d.up.fill",
                    tint: .green
                )
            }

            HStack(alignment: .top, spacing: 10) {
                Label(presentation.pointsText, systemImage: "mappin.and.ellipse")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(presentation.safetyDetail)
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
                        value: presentation.compactElapsedText,
                        systemImage: "clock",
                        tint: .blue
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WalkLiveActivityMetricTileView(
                        title: "영역",
                        value: presentation.compactAreaText,
                        systemImage: "square.stack.3d.up.fill",
                        tint: .green
                    )
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
                        Text(presentation.safetyDetail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                }
            } compactLeading: {
                Text(presentation.compactElapsedText)
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
