import SwiftUI

struct MapSeasonTileDetailCardView: View {
    let detail: MapSeasonTileDetailPresentation
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.title)
                        .font(.appFont(for: .ExtraBold, size: 16))
                        .foregroundStyle(MapChromePalette.primaryText)
                    Text(detail.contributionLine)
                        .font(.appFont(for: .Regular, size: 11))
                        .foregroundStyle(MapChromePalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(MapChromePalette.secondaryText)
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("map.season.detail.close")
            }

            HStack(spacing: 8) {
                badge(text: detail.statusTitle, tone: detail.statusTitle == "점령" ? .accent : .success)
                badge(text: detail.intensityTitle, tone: .neutral)
            }

            detailRow(
                title: "왜 이렇게 보여요?",
                text: detail.reasonLine,
                accessibilityIdentifier: "map.season.detail.reason"
            )
            detailRow(
                title: "다음 산책 힌트",
                text: detail.nextActionLine,
                accessibilityIdentifier: "map.season.detail.nextAction"
            )
        }
        .padding(14)
        .mapChromeSurface(emphasized: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.season.detail.card")
    }

    /// 상태 배지를 렌더링합니다.
    /// - Parameters:
    ///   - text: 배지에 표시할 문구입니다.
    ///   - tone: 배지 강조 톤입니다.
    /// - Returns: 시즌 타일 상태/강도 배지 뷰입니다.
    private func badge(text: String, tone: MapChromePillTone) -> some View {
        Text(text)
            .font(.appFont(for: .SemiBold, size: 11))
            .foregroundStyle(MapChromePalette.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .mapChromePill(tone)
    }

    /// 상세 패널의 설명 블록 한 줄을 렌더링합니다.
    /// - Parameters:
    ///   - title: 행 제목입니다.
    ///   - text: 사용자에게 보여줄 설명 문구입니다.
    ///   - accessibilityIdentifier: UI 테스트용 식별자입니다.
    /// - Returns: 제목과 본문을 포함한 설명 블록입니다.
    private func detailRow(
        title: String,
        text: String,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appFont(for: .SemiBold, size: 11))
                .foregroundStyle(MapChromePalette.primaryText)
            Text(text)
                .font(.appFont(for: .Regular, size: 11))
                .foregroundStyle(MapChromePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
