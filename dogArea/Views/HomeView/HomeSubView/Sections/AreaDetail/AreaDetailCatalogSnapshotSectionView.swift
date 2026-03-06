import SwiftUI

struct AreaDetailCatalogSnapshotSectionView: View {
    let metrics: [AreaReferenceCatalogMetricItem]
    let currentBandTitle: String
    let currentBandBody: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("카탈로그 스냅샷")
                .font(.appScaledFont(for: .SemiBold, size: 20, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(metrics) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        Text(item.value)
                            .font(.appScaledFont(for: .SemiBold, size: 22, relativeTo: .title3))
                            .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xFEF3C7))
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                        Text(item.detail)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                            .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
                    .padding(14)
                    .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(currentBandTitle)
                    .font(.appScaledFont(for: .SemiBold, size: 15, relativeTo: .headline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))
                Text(currentBandBody)
                    .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.appDynamicHex(light: 0xF8FAFC, dark: 0x0F172A, alpha: 0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.appDynamicHex(light: 0xCBD5E1, dark: 0x334155), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityIdentifier("areaDetail.catalogSnapshot")
    }
}
