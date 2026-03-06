import SwiftUI

struct AreaDetailReferenceCatalogSectionView: View {
    let sections: [AreaReferenceSection]
    let sourceText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("비교군 카탈로그")
                        .font(.appScaledFont(for: .SemiBold, size: 20, relativeTo: .headline))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    Text("소스: \(sourceText)")
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                }
                Spacer(minLength: 0)
            }

            ForEach(sections, id: \.id) { section in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.catalogName)
                                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                            Text("\(section.references.count)개 기준")
                                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        }
                        Spacer(minLength: 0)
                    }

                    ForEach(Array(section.references.prefix(5)), id: \.id) { reference in
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reference.referenceName)
                                    .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .subheadline))
                                    .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))
                                    .lineLimit(1)
                                Text(reference.areaM2.calculatedAreaString)
                                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0x94A3B8))
                            }
                            Spacer(minLength: 0)
                            if reference.isFeatured {
                                Text("FEATURED")
                                    .font(.appScaledFont(for: .SemiBold, size: 10, relativeTo: .caption2))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.appDynamicHex(light: 0xFEF3C7, dark: 0x78350F, alpha: 0.35))
                                    .foregroundStyle(Color.appDynamicHex(light: 0xB45309, dark: 0xFDE68A))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
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
