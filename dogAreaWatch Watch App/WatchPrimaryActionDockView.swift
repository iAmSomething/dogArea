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
        VStack(alignment: .leading, spacing: 8) {
            Text(isWalking ? "지금 할 수 있는 조작" : "바로 시작할 수 있어요")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

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
            VStack(alignment: .leading, spacing: 4) {
                Text("불필요한 정보 없이 시작 버튼을 먼저 보여줍니다.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                WatchActionButtonView(
                    presentation: startWalkPresentation,
                    action: onStartWalk
                )
            }
        }
    }
}
