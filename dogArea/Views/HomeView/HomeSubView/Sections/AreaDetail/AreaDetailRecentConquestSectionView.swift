import SwiftUI

struct AreaDetailRecentConquestSectionView: View {
    let items: [AreaMeterDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("최근 정복 기록")
                .font(.appScaledFont(for: .SemiBold, size: 20, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            if items.isEmpty {
                Text("아직 정복 기록이 없어요. 비교군을 확인한 뒤 첫 산책을 시작해보세요.")
                    .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(index == 0 ? Color.appGreen : Color.appDynamicHex(light: 0xCBD5E1, dark: 0x475569))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.areaName)
                                .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .subheadline))
                                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                            Text(item.createdAt.createdAtTimeDescriptionSimple + " · +\(item.area.calculatedAreaString)")
                                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0x94A3B8))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
}
