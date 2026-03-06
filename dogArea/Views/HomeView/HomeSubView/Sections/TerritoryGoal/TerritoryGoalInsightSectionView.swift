import SwiftUI

struct TerritoryGoalInsightSectionView: View {
    struct Item: Identifiable {
        let id: String
        let title: String
        let value: String
        let detail: String
        let accentColor: Color
    }

    let items: [Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("인사이트 요약")
                .font(.appScaledFont(for: .SemiBold, size: 20, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        Text(item.value)
                            .font(.appScaledFont(for: .SemiBold, size: 24, relativeTo: .title3))
                            .foregroundStyle(item.accentColor)
                        Text(item.detail)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                            .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
                    .padding(14)
                    .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}
