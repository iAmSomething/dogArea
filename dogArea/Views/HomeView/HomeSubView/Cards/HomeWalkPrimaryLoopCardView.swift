import SwiftUI

struct HomeWalkPrimaryLoopGuideSheetView: View {
    let presentation: HomeWalkPrimaryLoopPresentation
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summarySection
                    metricSection
                    guideSection
                    secondaryFlowSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .background(Color.appTabScaffoldBackground.ignoresSafeArea())
            .navigationTitle("산책 가이드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기", action: onClose)
                        .accessibilityIdentifier("home.walkPrimaryLoop.guide.close")
                }
            }
        }
        .accessibilityIdentifier("home.walkPrimaryLoop.guide.sheet")
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(presentation.badgeText)
                .appPill(isActive: true)
            Text(presentation.title)
                .font(.appScaledFont(for: .SemiBold, size: 22, relativeTo: .title3))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text(presentation.summaryText)
                .font(.appScaledFont(for: .Regular, size: 14, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var metricSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("지금 보는 기준")
                .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10, alignment: .top),
                    GridItem(.flexible(), spacing: 10, alignment: .top),
                    GridItem(.flexible(), spacing: 10, alignment: .top)
                ],
                spacing: 10
            ) {
                ForEach(presentation.metrics) { metric in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metric.title)
                            .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        Text(metric.value)
                            .font(.appScaledFont(for: .SemiBold, size: 17, relativeTo: .headline))
                            .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                        Text(metric.detail)
                            .font(.appScaledFont(for: .Regular, size: 10, relativeTo: .caption2))
                            .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x1E293B, alpha: 0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private var guideSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("왜 산책이 먼저인가요?")
                .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            ForEach(presentation.pillars) { pillar in
                VStack(alignment: .leading, spacing: 4) {
                    Text(pillar.title)
                        .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .subheadline))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    Text(pillar.body)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x243244, alpha: 0.84))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("home.walkPrimaryLoop.guide.pillar.\(pillar.id)")
            }
        }
    }

    private var secondaryFlowSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("보조 흐름")
                .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .subheadline))
                .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFCD34D))
            Text(presentation.secondaryFlowText)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFCD34D))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appDynamicHex(light: 0xFFF7ED, dark: 0x2A2114, alpha: 0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct HomeWalkPrimaryLoopCardView: View {
    let presentation: HomeWalkPrimaryLoopPresentation
    let onOpenGuide: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(presentation.badgeText)
                    .appPill(isActive: true)
                Spacer(minLength: 8)
                Button(action: onOpenGuide) {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 11, weight: .semibold))
                        Text("설명 보기")
                            .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                    }
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.walkPrimaryLoop.openGuide")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.title)
                    .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    .lineLimit(2)
                Text(presentation.summaryText)
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                ForEach(presentation.metrics) { metric in
                    compactMetricCard(metric)
                }
            }

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFCD34D))
                Text(presentation.secondaryFlowText)
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFCD34D))
                    .lineLimit(2)
            }
        }
        .appCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.walkPrimaryLoop.card")
        .accessibilityLabel(presentation.accessibilityText)
    }

    /// 홈 기본 루프 카드의 compact metric tile을 렌더링합니다.
    /// - Parameter metric: 타일에 표시할 metric 프레젠테이션입니다.
    /// - Returns: title/value 중심의 compact metric 카드입니다.
    private func compactMetricCard(_ metric: HomeWalkPrimaryLoopMetricPresentation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.title)
                .font(.appScaledFont(for: .Regular, size: 10, relativeTo: .caption2))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .lineLimit(1)
            Text(metric.value)
                .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x1E293B, alpha: 0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
