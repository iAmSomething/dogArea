import SwiftUI

struct WatchWalkCompletionSummarySheetView: View {
    let summary: WatchWalkCompletionSummaryState
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(summary.title, systemImage: summary.tone.symbolName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(summary.tone.tintColor)
                    Text(summary.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                WatchWalkSummaryMetricGridView(
                    elapsedTime: summary.elapsedTime,
                    area: summary.area,
                    pointCount: summary.pointCount,
                    petName: summary.petName
                )

                Text(summary.followUpNote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("확인") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
}
