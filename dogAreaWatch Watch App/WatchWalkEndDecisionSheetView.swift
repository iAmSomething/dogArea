import SwiftUI

struct WatchWalkEndDecisionSheetView: View {
    let elapsedTime: TimeInterval
    let area: Double
    let pointCount: Int
    let petName: String
    let isReachable: Bool
    let onSaveAndEnd: () -> Void
    let onContinueWalking: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("산책을 마칠까요?")
                        .font(.headline.weight(.semibold))
                    Text(headerDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                WatchWalkSummaryMetricGridView(
                    elapsedTime: elapsedTime,
                    area: area,
                    pointCount: pointCount,
                    petName: petName
                )

                VStack(spacing: 8) {
                    WatchActionButtonView(
                        presentation: WatchActionControlPresentation(
                            title: "저장하고 종료",
                            detail: isReachable
                                ? "현재 기록을 저장하고 산책을 마칩니다"
                                : "오프라인 큐에 넣고 연결 후 저장합니다",
                            tone: .success,
                            isDisabled: false,
                            showsProgress: false
                        ),
                        action: onSaveAndEnd
                    )
                    WatchActionButtonView(
                        presentation: WatchActionControlPresentation(
                            title: "계속 걷기",
                            detail: "산책 상태를 그대로 유지합니다",
                            tone: .neutral,
                            isDisabled: false,
                            showsProgress: false
                        ),
                        action: onContinueWalking
                    )
                    WatchActionButtonView(
                        presentation: WatchActionControlPresentation(
                            title: "기록 폐기",
                            detail: isReachable
                                ? "이번 산책 기록을 저장하지 않고 삭제합니다"
                                : "연결 후 폐기 요청을 보낼 때까지 현재 상태를 유지합니다",
                            tone: .warning,
                            isDisabled: false,
                            showsProgress: false
                        ),
                        action: onDiscard
                    )
                }
            }
            .padding()
        }
    }

    private var headerDetail: String {
        if isReachable {
            return "손목에서 바로 저장·계속·폐기를 고를 수 있어요."
        }
        return "지금은 오프라인이라 선택한 종료 요청을 큐에 저장하고, 반영 후 요약을 다시 보여줘요."
    }
}
