import SwiftUI

struct HomeWeatherGuidanceSheetView: View {
    let presentation: HomeWeatherGuidancePresentation
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summaryCard
                    profileCard
                    sectionStack
                    footerCard
                }
                .padding(16)
            }
            .accessibilityIdentifier("sheet.home.weatherGuidance")
            .background(Color.appTabScaffoldBackground)
            .navigationTitle("오늘 산책 가이드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        onClose()
                    }
                    .accessibilityIdentifier("sheet.home.weatherGuidance.close")
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(presentation.title)
                .font(.appFont(for: .SemiBold, size: 24))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text(presentation.subtitle)
                .font(.appFont(for: .Light, size: 13))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)
            Text(presentation.observedSummaryText)
                .font(.appFont(for: .Regular, size: 12))
                .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))
                .padding(.top, 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x31230D))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xFED7AA, dark: 0x78350F), lineWidth: 1)
        )
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.profileTitle)
                .font(.appFont(for: .SemiBold, size: 14))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(presentation.profileBadges) { badge in
                    Text(badge.title)
                        .font(.appFont(for: .SemiBold, size: 12))
                        .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFEF3C7))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 36)
                        .background(Color.appDynamicHex(light: 0xFFFBEB, dark: 0x3B2A10))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            if let profileFallbackNotice = presentation.profileFallbackNotice {
                Text(profileFallbackNotice)
                    .font(.appFont(for: .Light, size: 12))
                    .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFED7AA))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.weather.guidance.fallback")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x16202E))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
    }

    private var sectionStack: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(presentation.sections) { section in
                sectionCard(section)
            }
        }
    }

    /// 날씨 가이드 시트의 섹션 카드를 렌더링합니다.
    /// - Parameter section: 제목/설명/행동 항목이 들어 있는 가이드 섹션입니다.
    /// - Returns: 홈 날씨 가이드 시트에서 재사용되는 섹션 카드 뷰입니다.
    private func sectionCard(_ section: HomeWeatherGuidanceSectionPresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.appFont(for: .SemiBold, size: 16))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text(section.subtitle)
                .font(.appFont(for: .Light, size: 12))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(section.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.appFont(for: .SemiBold, size: 13))
                            .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                        Text(item.body)
                            .font(.appFont(for: .Light, size: 12))
                            .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(Color.appDynamicHex(light: 0xF8FAFC, dark: 0x0F172A))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x16202E))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
        .accessibilityIdentifier("home.weather.guidance.section.\(section.id)")
    }

    private var footerCard: some View {
        Text(presentation.footerText)
            .font(.appFont(for: .Light, size: 11))
            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0x94A3B8))
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appDynamicHex(light: 0xF8FAFC, dark: 0x0F172A))
            )
            .accessibilityLabel(presentation.accessibilityText)
    }
}
