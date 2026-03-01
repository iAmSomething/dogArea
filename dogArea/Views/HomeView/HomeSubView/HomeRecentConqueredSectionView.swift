import SwiftUI

struct HomeRecentConqueredSectionView: View {
    let items: [AreaMeterDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("최근 정복한 영역")
                    .font(.appScaledFont(for: .SemiBold, size: 30, relativeTo: .title2))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0xCBD5E1))
            }

            if items.isEmpty {
                homeEmptyTerritoryCard
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    recentTerritoryRow(item: item, isNew: index == 0, colorSeed: index)
                }
                homeEmptyTerritoryCard
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("최근 정복 영역 목록")
    }

    /// 최근 정복 영역 리스트의 단일 행을 렌더링합니다.
    /// - Parameters:
    ///   - item: 표시할 영역 DTO입니다.
    ///   - isNew: 최신 항목 여부입니다.
    ///   - colorSeed: 썸네일 색상 시드를 위한 인덱스입니다.
    /// - Returns: 최근 정복 영역 행 뷰입니다.
    private func recentTerritoryRow(item: AreaMeterDTO, isNew: Bool, colorSeed: Int) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(recentThumbnailColor(for: colorSeed))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.areaName)
                    .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    .lineLimit(1)
                Text(item.createdAt.createdAtTimeDescriptionSimple + " · +\(item.area.calculatedAreaString)")
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0x94A3B8))
                    .lineLimit(1)
            }
            Spacer()
            if isNew {
                Text("NEW")
                    .font(.appScaledFont(for: .SemiBold, size: 10, relativeTo: .caption2))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.appDynamicHex(light: 0xDCFCE7, dark: 0x166534))
                    .foregroundStyle(Color.appDynamicHex(light: 0x16A34A, dark: 0xDCFCE7))
                    .cornerRadius(9)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appDynamicHex(light: 0xCBD5E1, dark: 0x64748B))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
        .cornerRadius(14)
    }

    /// 최근 정복 섹션의 빈 상태 카드를 렌더링합니다.
    private var homeEmptyTerritoryCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.walk")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.appDynamicHex(light: 0xEAB308, dark: 0xFACC15))
            Text("산책을 통해 영역을 넓혀봐요!")
                .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xCBD5E1))
            Text("새로운 장소를 갈 때마다 영역이 확장됩니다.")
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .footnote))
                .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x64748B))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    Color.appDynamicHex(light: 0xEAB308, dark: 0xFACC15, alpha: 0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 2])
                )
        )
    }

    /// 최근 정복 썸네일에 사용할 인덱스 기반 색상을 반환합니다.
    /// - Parameter index: 리스트 인덱스 값입니다.
    /// - Returns: 지정 인덱스에 대응하는 썸네일 배경색입니다.
    private func recentThumbnailColor(for index: Int) -> Color {
        let palette: [Color] = [
            Color.appDynamicHex(light: 0x10B981, dark: 0x047857),
            Color.appDynamicHex(light: 0x94A3B8, dark: 0x475569),
            Color.appDynamicHex(light: 0x3B82F6, dark: 0x1D4ED8)
        ]
        return palette[index % palette.count]
    }
}
