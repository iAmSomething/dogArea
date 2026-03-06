import SwiftUI

struct TerritoryGoalRecentListSectionView: View {
    let items: [AreaMeterDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("최근 정복 영역")
                    .font(.appScaledFont(for: .SemiBold, size: 20, relativeTo: .headline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0xCBD5E1))
            }

            if items.isEmpty {
                Text("아직 최근 정복 기록이 없어요. 첫 산책을 시작하면 최근 정복 목록이 채워집니다.")
                    .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    TerritoryGoalRecentRowView(item: item, isNew: index == 0, colorSeed: index)
                }
            }
        }
    }
}

private struct TerritoryGoalRecentRowView: View {
    let item: AreaMeterDTO
    let isNew: Bool
    let colorSeed: Int

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(thumbnailColor)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.9))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.areaName)
                    .font(.appScaledFont(for: .SemiBold, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    .lineLimit(1)
                Text(item.createdAt.createdAtTimeDescriptionSimple)
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0x94A3B8))
                Text("확장 면적 +\(item.area.calculatedAreaString)")
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xCBD5E1))
            }

            Spacer(minLength: 0)

            if isNew {
                Text("NEW")
                    .font(.appScaledFont(for: .SemiBold, size: 10, relativeTo: .caption2))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.appDynamicHex(light: 0xDCFCE7, dark: 0x166534))
                    .foregroundStyle(Color.appDynamicHex(light: 0x16A34A, dark: 0xDCFCE7))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var thumbnailColor: Color {
        let palette: [Color] = [
            Color.appDynamicHex(light: 0x10B981, dark: 0x047857),
            Color.appDynamicHex(light: 0x94A3B8, dark: 0x475569),
            Color.appDynamicHex(light: 0x3B82F6, dark: 0x1D4ED8)
        ]
        return palette[colorSeed % palette.count]
    }
}
