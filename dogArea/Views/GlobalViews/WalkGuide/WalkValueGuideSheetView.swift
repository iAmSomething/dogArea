import SwiftUI

struct WalkValueGuideSheetView: View {
    let presentation: WalkValueGuidePresentation
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    flowSection
                    policySection
                    revisitSection
                }
                .padding(16)
            }
            .navigationTitle("산책 설명")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기", action: onClose)
                        .accessibilityIdentifier("map.walk.guide.close")
                }
            }
            .accessibilityIdentifier("map.walk.guide.sheet")
        }
    }

    /// 산책 가치 가이드 상단의 맥락/제목/핵심 요약 섹션을 구성합니다.
    /// - Returns: 사용자가 현재 시트의 목적을 빠르게 이해할 수 있는 헤더 뷰입니다.
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.badgeText)
                .font(.appFont(for: .SemiBold, size: 11))
                .foregroundStyle(Color.appInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale.opacity(0.9))
                .clipShape(Capsule())
                .accessibilityIdentifier("map.walk.guide.context")

            Text(presentation.title)
                .font(.appFont(for: .ExtraBold, size: 24))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            Text(presentation.subtitle)
                .font(.appFont(for: .Regular, size: 14))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)

            Text(presentation.heroLine)
                .font(.appFont(for: .SemiBold, size: 14))
                .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x3F2A12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("map.walk.guide.hero")
        }
    }

    /// 시작 전, 진행 중, 저장 후 흐름을 단계형 카드로 노출합니다.
    /// - Returns: 산책 가치 설명의 핵심 3단계 카드 섹션입니다.
    private var flowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("산책 가치 흐름")
                .font(.appFont(for: .SemiBold, size: 16))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            ForEach(presentation.flowSteps) { step in
                VStack(alignment: .leading, spacing: 6) {
                    Text(step.badgeText)
                        .font(.appFont(for: .SemiBold, size: 11))
                        .foregroundStyle(Color.appInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appYellowPale.opacity(0.9))
                        .clipShape(Capsule())
                    Text(step.title)
                        .font(.appFont(for: .SemiBold, size: 14))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    Text(step.body)
                        .font(.appFont(for: .Regular, size: 12))
                        .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("map.walk.guide.flow.\(step.id)")
            }
        }
    }

    /// 설명 노출 정책을 짧게 안내합니다.
    /// - Returns: compact helper와 저장 후 카드 정책을 설명하는 섹션입니다.
    private var policySection: some View {
        Text(presentation.compactPolicyLine)
            .font(.appFont(for: .Regular, size: 13))
            .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appDynamicHex(light: 0xF8FAFC, dark: 0x0F172A))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityIdentifier("map.walk.guide.policy")
    }

    /// 가이드 재진입 경로를 안내합니다.
    /// - Returns: 사용자가 나중에 설명을 다시 찾을 수 있는 footer 문구입니다.
    private var revisitSection: some View {
        Text(presentation.revisitLine)
            .font(.appFont(for: .Regular, size: 12))
            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("map.walk.guide.revisit")
    }
}
