import SwiftUI

struct SeasonGuideSheetView: View {
    let presentation: SeasonGuidePresentation
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    conceptSection
                    repeatWalkRuleSection
                    flowSection
                    revisitSection
                }
                .padding(16)
            }
            .navigationTitle("시즌 가이드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기", action: onClose)
                        .accessibilityIdentifier("season.guide.close")
                }
            }
            .accessibilityIdentifier("season.guide.sheet")
        }
    }

    /// 시즌 가이드 시트 상단의 맥락/제목/핵심 요약 섹션을 구성합니다.
    /// - Returns: 사용자가 현재 시트의 목적을 한 번에 이해할 수 있는 헤더 뷰입니다.
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.badgeText)
                .font(.appFont(for: .SemiBold, size: 11))
                .foregroundStyle(Color.appInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale.opacity(0.9))
                .clipShape(Capsule())
                .accessibilityIdentifier("season.guide.context")

            VStack(alignment: .leading, spacing: 6) {
                Text(presentation.title)
                    .font(.appFont(for: .ExtraBold, size: 24))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Text(presentation.subtitle)
                    .font(.appFont(for: .Regular, size: 14))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(presentation.heroLine)
                .font(.appFont(for: .SemiBold, size: 14))
                .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x3F2A12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("season.guide.hero")
        }
    }

    /// 시즌 핵심 개념 카드를 세로 스택으로 노출합니다.
    /// - Returns: 시즌 타일/점령/유지/새 칸 가치 카드 섹션입니다.
    private var conceptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("핵심 개념")
                .font(.appFont(for: .SemiBold, size: 16))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            ForEach(presentation.conceptItems) { item in
                conceptCard(for: item)
                    .accessibilityIdentifier(seasonGuideConceptIdentifier(for: item))
            }
        }
    }

    /// 반복 산책 규칙을 별도 주의 카드로 노출합니다.
    /// - Returns: 반복 경로 규칙을 설명하는 카드 뷰입니다.
    private var repeatWalkRuleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("왜 같은 길만 반복하면 덜 오를 수 있나요?")
                .font(.appFont(for: .SemiBold, size: 16))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text(presentation.repeatWalkRuleLine)
                .font(.appFont(for: .Regular, size: 13))
                .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appDynamicHex(light: 0xFEF3C7, dark: 0x3F2D0B))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("season.guide.rule.repeatWalk")
        }
    }

    /// 산책부터 시즌 결과까지 이어지는 흐름을 단계형으로 노출합니다.
    /// - Returns: 행동-결과 흐름 단계 섹션입니다.
    private var flowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("산책이 시즌으로 이어지는 흐름")
                .font(.appFont(for: .SemiBold, size: 16))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            ForEach(presentation.flowSteps) { step in
                flowStepRow(for: step)
                    .accessibilityIdentifier("season.guide.flow.\(step.stepNumber)")
            }
        }
    }

    /// 사용자가 나중에 다시 가이드를 찾을 수 있는 재진입 문구를 보여줍니다.
    /// - Returns: 재진입 정책을 설명하는 footer 뷰입니다.
    private var revisitSection: some View {
        Text(presentation.revisitLine)
            .font(.appFont(for: .Regular, size: 12))
            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("season.guide.revisit")
    }

    /// 시즌 핵심 개념 카드 하나를 구성합니다.
    /// - Parameter item: 카드에 노출할 시즌 개념 데이터입니다.
    /// - Returns: 아이콘, 제목, 설명을 포함한 개념 카드 뷰입니다.
    private func conceptCard(for item: SeasonGuideConceptPresentation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.appYellow)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.appFont(for: .SemiBold, size: 14))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Text(item.body)
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 시즌 행동-결과 흐름 단계 한 줄을 구성합니다.
    /// - Parameter step: 현재 단계에 노출할 흐름 설명 데이터입니다.
    /// - Returns: 번호 뱃지와 제목/본문을 묶은 단계 행 뷰입니다.
    private func flowStepRow(for step: SeasonGuideFlowStepPresentation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step.stepNumber)")
                .font(.appFont(for: .SemiBold, size: 12))
                .foregroundStyle(Color.appInk)
                .frame(width: 24, height: 24)
                .background(Color.appYellowPale)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.appFont(for: .SemiBold, size: 14))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Text(step.body)
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appDynamicHex(light: 0xF8FAFC, dark: 0x0F172A))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// 시즌 개념 카드의 안정적인 접근성 식별자를 반환합니다.
    /// - Parameter item: 식별자를 계산할 시즌 개념 카드 데이터입니다.
    /// - Returns: UI 테스트와 접근성 탐색에 사용할 고정 식별자입니다.
    private func seasonGuideConceptIdentifier(for item: SeasonGuideConceptPresentation) -> String {
        switch item.id {
        case "tile":
            return "season.guide.concept.tile"
        case "occupied":
            return "season.guide.concept.occupied"
        case "maintained":
            return "season.guide.concept.maintained"
        case "newTile":
            return "season.guide.concept.newTile"
        default:
            return "season.guide.concept.\(item.id)"
        }
    }
}
