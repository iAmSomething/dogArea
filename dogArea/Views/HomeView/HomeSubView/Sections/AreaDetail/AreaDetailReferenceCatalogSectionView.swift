import SwiftUI

struct AreaDetailReferenceCatalogSectionView: View {
    let sections: [AreaReferenceCatalogSectionViewData]
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
                            Text(section.title)
                                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                            Text(section.summaryText)
                                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        }
                        Spacer(minLength: 0)
                    }

                    ForEach(section.rows, id: \.id) { reference in
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reference.name)
                                    .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .subheadline))
                                    .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))
                                    .lineLimit(1)
                                Text(reference.areaText)
                                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0x94A3B8))
                            }
                            Spacer(minLength: 0)
                            if reference.tags.isEmpty == false {
                                VStack(alignment: .trailing, spacing: 6) {
                                    ForEach(reference.tags) { tag in
                                        Text(tag.title)
                                            .font(.appScaledFont(for: .SemiBold, size: 10, relativeTo: .caption2))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(tagBackgroundColor(for: tag.style))
                                            .foregroundStyle(tagForegroundColor(for: tag.style))
                                            .clipShape(Capsule())
                                    }
                                }
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

    /// 배지 스타일에 대응하는 배경색을 반환합니다.
    /// - Parameter style: 렌더링할 배지 스타일입니다.
    /// - Returns: 스타일에 대응하는 배경 `Color`입니다.
    private func tagBackgroundColor(for style: AreaReferenceCatalogTag.Style) -> Color {
        switch style {
        case .primary:
            return Color.appDynamicHex(light: 0xFEF3C7, dark: 0x78350F, alpha: 0.5)
        case .secondary:
            return Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155, alpha: 0.8)
        case .success:
            return Color.appDynamicHex(light: 0xDCFCE7, dark: 0x166534, alpha: 0.8)
        case .neutral:
            return Color.appDynamicHex(light: 0xF1F5F9, dark: 0x334155, alpha: 0.9)
        }
    }

    /// 배지 스타일에 대응하는 전경색을 반환합니다.
    /// - Parameter style: 렌더링할 배지 스타일입니다.
    /// - Returns: 스타일에 대응하는 전경 `Color`입니다.
    private func tagForegroundColor(for style: AreaReferenceCatalogTag.Style) -> Color {
        switch style {
        case .primary:
            return Color.appDynamicHex(light: 0x92400E, dark: 0xFDE68A)
        case .secondary:
            return Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0)
        case .success:
            return Color.appDynamicHex(light: 0x166534, dark: 0xDCFCE7)
        case .neutral:
            return Color.appDynamicHex(light: 0x475569, dark: 0xE2E8F0)
        }
    }
}
