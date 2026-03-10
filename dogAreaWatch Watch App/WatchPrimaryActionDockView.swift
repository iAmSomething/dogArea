import SwiftUI

struct WatchPrimaryActionDockView: View {
    let isWalking: Bool
    let startWalkPresentation: WatchActionControlPresentation
    let addPointPresentation: WatchActionControlPresentation
    let endWalkPresentation: WatchActionControlPresentation
    let onStartWalk: () -> Void
    let onAddPoint: () -> Void
    let onEndWalk: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isWalking ? "지금 할 수 있는 조작" : "지금 시작할 수 있어요")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(isWalking ? "포인트 추가와 종료를 빠르게 누를 수 있어요." : "불필요한 정보 없이 시작 버튼을 먼저 보여줍니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if isWalking {
                WatchActionButtonView(
                    presentation: addPointPresentation,
                    action: onAddPoint
                )
                WatchActionButtonView(
                    presentation: endWalkPresentation,
                    action: onEndWalk
                )
            } else {
                WatchActionButtonView(
                    presentation: startWalkPresentation,
                    action: onStartWalk
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("watch.main.actionsDock")
    }
}
