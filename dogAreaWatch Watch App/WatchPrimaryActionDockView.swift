import SwiftUI

struct WatchPrimaryActionDockView: View {
    let isWalking: Bool
    let startWalkPresentation: WatchActionControlPresentation
    let addPointPresentation: WatchActionControlPresentation
    let endWalkPresentation: WatchActionControlPresentation
    let onStartWalk: () -> Void
    let onAddPoint: () -> Void
    let onEndWalk: () -> Void
    var showsBackground: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isWalking ? "지금 할 수 있는 조작" : "먼저 할 일")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(sectionDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            actionButtons
        }
        .padding(showsBackground ? 10 : 0)
        .background {
            if showsBackground {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("watch.main.actionsDock")
    }

    /// 현재 산책 진행 상태에 맞는 조작 버튼 블록을 렌더링합니다.
    /// - Returns: idle 또는 walking 상태에 맞는 조작 버튼 묶음 뷰입니다.
    @ViewBuilder
    private var actionButtons: some View {
        if isWalking {
            VStack(spacing: 8) {
                WatchActionButtonView(
                    presentation: addPointPresentation,
                    action: onAddPoint
                )
                WatchActionButtonView(
                    presentation: endWalkPresentation,
                    action: onEndWalk
                )
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                WatchActionButtonView(
                    presentation: startWalkPresentation,
                    action: onStartWalk
                )
            }
        }
    }

    private var sectionDetail: String {
        isWalking ? "포인트 추가와 종료만 빠르게 남겨 둡니다." : "지금 이 화면에서는 산책 시작만 보여 줍니다."
    }
}
