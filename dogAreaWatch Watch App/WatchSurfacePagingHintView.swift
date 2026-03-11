import SwiftUI

struct WatchSurfacePagingHintView: View {
    let currentSurface: WatchMainSurface
    let targetSurfaceLabel: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.left.and.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(hintText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("watch.main.surfaceHint")
    }

    /// 현재 페이지에서 반대 surface로 이동하는 방식을 짧게 설명합니다.
    /// - Returns: watch paging affordance를 설명하는 한 줄 안내 문구입니다.
    private var hintText: String {
        switch currentSurface {
        case .control:
            return "옆으로 넘겨 \(targetSurfaceLabel)을 확인하세요."
        case .info:
            return "옆으로 넘겨 \(targetSurfaceLabel)으로 돌아가세요."
        }
    }
}
