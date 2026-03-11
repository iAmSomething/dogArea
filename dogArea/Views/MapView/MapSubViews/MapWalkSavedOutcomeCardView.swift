import SwiftUI

struct MapWalkSavedOutcomeCardView: View {
    let presentation: MapWalkSavedOutcomePresentation
    let onOpenHistory: () -> Void
    let onOpenDetail: () -> Void
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

            VStack(spacing: 8) {
                actionButton(
                    title: presentation.primaryActionTitle,
                    foregroundStyle: Color.white,
                    backgroundStyle: Color.appInk,
                    strokeColor: nil,
                    identifier: "map.walk.savedOutcome.openHistory",
                    action: onOpenHistory
                )

                actionButton(
                    title: presentation.secondaryActionTitle,
                    foregroundStyle: MapChromePalette.primaryText,
                    backgroundStyle: Color.white.opacity(0.001),
                    strokeColor: MapChromePalette.surfaceBorder,
                    identifier: "map.walk.savedOutcome.openDetail",
                    action: onOpenDetail
                )
            }
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

    /// 저장 직후 카드 하단의 주요 행동 버튼을 공통 스타일로 구성합니다.
    /// - Parameters:
    ///   - title: 버튼 제목입니다.
    ///   - foregroundStyle: 제목에 적용할 전경색입니다.
    ///   - backgroundStyle: 버튼 배경색입니다.
    ///   - strokeColor: 외곽선이 필요하면 전달합니다.
    ///   - identifier: 접근성 식별자입니다.
    ///   - action: 탭 시 수행할 동작입니다.
    /// - Returns: 전체 hit area와 시각 스타일이 고정된 버튼입니다.
    private func actionButton(
        title: String,
        foregroundStyle: Color,
        backgroundStyle: Color,
        strokeColor: Color?,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .body))
                .foregroundStyle(foregroundStyle)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(backgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            if let strokeColor {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            }
        }
        .accessibilityIdentifier(identifier)
    }
}
