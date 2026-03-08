import SwiftUI

struct WalkListDetailTimelineSectionView: View {
    let chips: [WalkListDetailTimelineChipModel]
    let footnote: String?
    let onSelect: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("포인트 타임라인")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text("포인트가 많을수록 대표 시점을 먼저 보여주고, 선택한 칩과 지도를 함께 읽을 수 있게 정리했습니다.")
                .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)

            if chips.isEmpty {
                Text("이 기록에는 표시할 포인트가 없어요.")
                    .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(chips) { chip in
                            Button {
                                onSelect(chip.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(chip.title)
                                        .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .subheadline))
                                    Text(chip.subtitle)
                                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                                    Text(chip.roleLabel)
                                        .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                                }
                                .foregroundStyle(chip.isSelected ? Color.appInk : Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))
                                .frame(width: 122, alignment: .leading)
                                .padding(12)
                                .background(
                                    chip.isSelected
                                        ? Color.appYellow
                                        : Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(
                                            chip.isSelected
                                                ? Color.appDynamicHex(light: 0xEAB308, dark: 0xFACC15)
                                                : Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(chip.isSelected ? "walklist.detail.point.selected" : "walklist.detail.point")
                        }
                    }
                }
            }

            if let footnote {
                Text(footnote)
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
            }
        }
        .appCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walklist.detail.timeline")
    }
}
