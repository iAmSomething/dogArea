import SwiftUI

struct HomeMissionGuideSheetView: View {
    let presentation: HomeMissionGuidePresentation
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    axisSection
                    comparisonSection
                    flowSection
                    revisitSection
                }
                .padding(16)
            }
            .navigationTitle("미션 설명")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기", action: onClose)
                        .accessibilityIdentifier("home.quest.help.close")
                }
            }
            .accessibilityIdentifier("home.quest.help.sheet")
        }
    }

    /// 홈 미션 도움말 상단의 핵심 요약 영역을 구성합니다.
    /// - Returns: 사용자가 sheet 목적과 현재 맥락을 즉시 이해할 수 있는 헤더 뷰입니다.
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.badgeText)
                .font(.appFont(for: .SemiBold, size: 11))
                .foregroundStyle(Color.appInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale.opacity(0.9))
                .clipShape(Capsule())

            Text(presentation.title)
                .font(.appScaledFont(for: .ExtraBold, size: 28, relativeTo: .title2))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            Text(presentation.subtitle)
                .font(.appScaledFont(for: .Regular, size: 14, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)

            Text(presentation.heroLine)
                .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x3F2A12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("home.quest.help.hero")
        }
    }

    /// 도움말 시트의 4축 설명 카드를 렌더링합니다.
    /// - Returns: 무엇/왜/어떻게/완료 후 변화를 순서대로 보여주는 섹션 뷰입니다.
    private var axisSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("핵심 설명")
                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            ForEach(presentation.sections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title)
                        .font(.appScaledFont(for: .SemiBold, size: 15, relativeTo: .headline))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    Text(section.body)
                        .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
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
                .accessibilityIdentifier(axisIdentifier(for: section))
            }
        }
    }

    /// 산책 기반 자동 기록과 실내 자가 기록의 차이를 비교 카드로 렌더링합니다.
    /// - Returns: 자동 추적과 자가 기록 흐름의 차이를 설명하는 비교 섹션 뷰입니다.
    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("어떤 점이 다른가요?")
                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            ForEach(presentation.comparisons) { comparison in
                VStack(alignment: .leading, spacing: 6) {
                    Text(comparison.title)
                        .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .headline))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    Text(comparison.body)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appDynamicHex(light: 0xF8FAFC, dark: 0x0F172A))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier(comparisonIdentifier(for: comparison))
            }
        }
    }

    /// 사용자가 지금 따라야 할 행동 순서를 단계 카드로 렌더링합니다.
    /// - Returns: 현재 미션 완료 흐름을 단계별로 보여주는 섹션 뷰입니다.
    private var flowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("지금은 이렇게 하면 돼요")
                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            ForEach(presentation.steps) { step in
                VStack(alignment: .leading, spacing: 6) {
                    Text(step.badgeText)
                        .font(.appFont(for: .SemiBold, size: 11))
                        .foregroundStyle(Color.appInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appYellowPale.opacity(0.9))
                        .clipShape(Capsule())
                    Text(step.title)
                        .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .headline))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    Text(step.body)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
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
                .accessibilityIdentifier(stepIdentifier(for: step))
            }
        }
    }

    /// 도움말 재진입 경로를 짧게 안내합니다.
    /// - Returns: 사용자가 나중에 가이드를 다시 찾을 수 있는 footer 뷰입니다.
    private var revisitSection: some View {
        Text(presentation.revisitLine)
            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .footnote))
            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("home.quest.help.revisit")
    }

    /// 홈 미션 설명 축 카드의 접근성 식별자를 반환합니다.
    /// - Parameter section: 식별자를 부여할 설명 축 프레젠테이션입니다.
    /// - Returns: UI 테스트와 VoiceOver 탐색에 사용할 고정 식별자 문자열입니다.
    private func axisIdentifier(for section: HomeMissionGuideAxisPresentation) -> String {
        switch section.id {
        case "what":
            return "home.quest.help.axis.what"
        case "why":
            return "home.quest.help.axis.why"
        case "how":
            return "home.quest.help.axis.how"
        case "outcome":
            return "home.quest.help.axis.outcome"
        default:
            return "home.quest.help.axis.\(section.id)"
        }
    }

    /// 홈 미션 비교 카드의 접근성 식별자를 반환합니다.
    /// - Parameter comparison: 식별자를 부여할 비교 카드 프레젠테이션입니다.
    /// - Returns: 자동 기록/자가 기록 비교 카드의 고정 식별자 문자열입니다.
    private func comparisonIdentifier(for comparison: HomeMissionGuideComparisonPresentation) -> String {
        switch comparison.id {
        case "auto":
            return "home.quest.help.compare.auto"
        case "manual":
            return "home.quest.help.compare.manual"
        default:
            return "home.quest.help.compare.\(comparison.id)"
        }
    }

    /// 홈 미션 단계 카드의 접근성 식별자를 반환합니다.
    /// - Parameter step: 식별자를 부여할 단계 프레젠테이션입니다.
    /// - Returns: 단계형 설명 카드의 고정 식별자 문자열입니다.
    private func stepIdentifier(for step: HomeMissionGuideStepPresentation) -> String {
        "home.quest.help.step.\(step.id)"
    }
}
