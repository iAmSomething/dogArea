import SwiftUI

struct WatchControlSurfaceView: View {
    let isWalking: Bool
    let isReachable: Bool
    let walkingTime: TimeInterval
    let walkingArea: Double
    let pointCount: Int
    let petContext: WatchSelectedPetContextState
    let feedbackBanner: WatchActionFeedbackBanner?
    let startWalkPresentation: WatchActionControlPresentation
    let addPointPresentation: WatchActionControlPresentation
    let endWalkPresentation: WatchActionControlPresentation
    let onStartWalk: () -> Void
    let onAddPoint: () -> Void
    let onEndWalk: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text("조작 화면")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer(minLength: 0)
                    Text(isWalking ? "걷는 중" : "시작 준비")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isWalking ? Color.green : Color.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill((isWalking ? Color.green : Color.orange).opacity(0.18))
                        )
                }

                Text(controlHeadline)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(controlDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("watch.main.controlSurface.header")

            WatchMainStatusSummaryView(
                isWalking: isWalking,
                isReachable: isReachable,
                walkingTime: walkingTime,
                walkingArea: walkingArea,
                pointCount: pointCount,
                petContext: petContext
            )

            if let feedbackBanner {
                WatchActionBannerView(
                    banner: feedbackBanner,
                    style: .inline
                )
            }

            WatchPrimaryActionDockView(
                isWalking: isWalking,
                startWalkPresentation: startWalkPresentation,
                addPointPresentation: addPointPresentation,
                endWalkPresentation: endWalkPresentation,
                onStartWalk: onStartWalk,
                onAddPoint: onAddPoint,
                onEndWalk: onEndWalk,
                showsBackground: false
            )
            .accessibilityIdentifier("watch.main.controlSurface.actions")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("watch.main.controlSurface")
    }

    private var controlHeadline: String {
        isWalking ? "포인트와 종료를 바로 조작합니다." : "산책 시작에만 집중합니다."
    }

    private var controlDetail: String {
        isWalking
            ? "지금 필요한 조작만 이 화면에 남겨 둡니다."
            : "상태 확인은 옆 정보 화면으로 분리했습니다."
    }
}
