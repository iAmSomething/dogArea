import SwiftUI

struct MapWalkSavedOutcomeCardView: View {
    let presentation: MapWalkSavedOutcomePresentation
    let onOpenHistory: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(presentation.title)
                        .font(.appScaledFont(for: .SemiBold, size: 15, relativeTo: .headline))
                        .foregroundStyle(MapChromePalette.primaryText)
                        .accessibilityIdentifier("map.walk.savedOutcome.state")
                    Text(presentation.statusBody)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(MapChromePalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(presentation.summary)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(MapChromePalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button("닫기", action: onDismiss)
                    .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption2))
                    .foregroundStyle(MapChromePalette.primaryText)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 10)
                    .mapChromePill(.neutral)
                    .accessibilityIdentifier("map.walk.savedOutcome.dismiss")
            }

            VStack(alignment: .leading, spacing: 8) {
                summaryRow(
                    title: "반영 요약",
                    body: presentation.appliedSummary,
                    identifier: "map.walk.savedOutcome.applied"
                )
                if let primaryReasonLine = presentation.primaryReasonLine {
                    summaryRow(
                        title: "제외 이유",
                        body: primaryReasonLine,
                        identifier: "map.walk.savedOutcome.reason"
                    )
                }
                summaryRow(
                    title: "이어지는 곳",
                    body: presentation.connectionLine,
                    identifier: "map.walk.savedOutcome.connection"
                )
            }

            Button(action: onOpenHistory) {
                Text(presentation.primaryActionTitle)
                    .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .body))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.appInk)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("map.walk.savedOutcome.openHistory")
        }
        .padding(12)
        .mapChromeSurface(emphasized: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.walk.savedOutcome.card")
    }

    /// 종료 직후 카드 안의 짧은 설명 행을 구성합니다.
    /// - Parameters:
    ///   - title: 설명 행 제목입니다.
    ///   - body: 설명 행 본문입니다.
    ///   - identifier: 접근성 식별자입니다.
    /// - Returns: 제목과 본문이 함께 보이는 설명 행 뷰입니다.
    private func summaryRow(title: String, body: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                .foregroundStyle(MapChromePalette.primaryText)
            Text(body)
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                .foregroundStyle(MapChromePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mapChromePill(.neutral)
        .accessibilityIdentifier(identifier)
    }
}
