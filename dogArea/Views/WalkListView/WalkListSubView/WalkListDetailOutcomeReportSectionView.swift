import SwiftUI

struct WalkListDetailOutcomeReportSectionView: View {
    let explanation: WalkOutcomeExplanationDTO

    @State private var isExclusionsExpanded: Bool = false
    @State private var isConnectionsExpanded: Bool = false
    @State private var isContributionExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            summarySection
            disclosureButton(
                title: isExclusionsExpanded ? "제외 이유 접기" : "제외 이유 보기",
                identifier: "walklist.detail.outcomeReport.exclusions.toggle",
                isExpanded: isExclusionsExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExclusionsExpanded.toggle()
                }
            }
            if isExclusionsExpanded {
                exclusionsSection
            }

            disclosureButton(
                title: isConnectionsExpanded ? "이어지는 흐름 접기" : "이어지는 흐름 보기",
                identifier: "walklist.detail.outcomeReport.connections.toggle",
                isExpanded: isConnectionsExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isConnectionsExpanded.toggle()
                }
            }
            if isConnectionsExpanded {
                connectionsSection
            }

            disclosureButton(
                title: isContributionExpanded ? "계산 근거 접기" : "계산 근거 보기",
                identifier: "walklist.detail.outcomeReport.contribution.toggle",
                isExpanded: isContributionExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isContributionExpanded.toggle()
                }
            }
            if isContributionExpanded {
                contributionSection
            }
        }
        .appCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walklist.detail.outcomeReport")
    }

    /// 상태 요약과 핵심 수치를 항상 펼친 상태로 렌더링합니다.
    /// - Returns: 산책 반영 상태를 가장 먼저 보여주는 요약 카드입니다.
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text(explanation.statusTitle)
                    .appPill(isActive: explanation.summaryState == .normalApplied)
                Spacer(minLength: 0)
                Text("제외 비율 \(explanation.excludedRatioText)")
                    .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
            }

            Text(explanation.statusBody)
                .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x475569, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                summaryMetricRow(
                    title: "반영된 포인트",
                    value: "\(explanation.appliedPointCount)개",
                    identifier: "walklist.detail.outcomeReport.summary.applied"
                )
                summaryMetricRow(
                    title: "제외된 포인트",
                    value: "\(explanation.excludedPointCount)개",
                    identifier: "walklist.detail.outcomeReport.summary.excluded"
                )
                if let primaryReasonLine = explanation.primaryReasonLine {
                    Text(primaryReasonLine)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("walklist.detail.outcomeReport.summary.reason")
                }
                Text(explanation.primaryConnectionLine)
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("walklist.detail.outcomeReport.summary.connection")
            }
        }
        .accessibilityIdentifier("walklist.detail.outcomeReport.summary")
    }

    /// 제외 사유 상세 섹션을 렌더링합니다.
    /// - Returns: 제외 reason row 또는 empty state를 담은 뷰입니다.
    private var exclusionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if explanation.topExclusionReasons.isEmpty {
                Text("이번 기록에는 크게 제외된 구간이 없어요.")
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("walklist.detail.outcomeReport.exclusions.empty")
            } else {
                ForEach(explanation.topExclusionReasons) { reason in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(reason.title)
                                .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .subheadline))
                                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                            Spacer(minLength: 0)
                            Text("\(reason.count)건")
                                .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                                .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
                        }
                        Text(reason.shortExplanation)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x1E293B, alpha: 0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("walklist.detail.outcomeReport.reason.\(reason.id)")
                }
            }
        }
    }

    /// 기록이 어디에 이어지는지 단계별로 렌더링합니다.
    /// - Returns: 기록/영역/시즌/미션 연결 row를 담은 뷰입니다.
    private var connectionsSection: some View {
        VStack(spacing: 10) {
            ForEach(explanation.connectionRows) { row in
                detailRow(
                    title: row.title,
                    badge: row.statusTitle,
                    body: row.detail,
                    identifier: "walklist.detail.outcomeReport.connection.\(row.id)"
                )
            }
        }
    }

    /// 계산 근거 상세 섹션을 렌더링합니다.
    /// - Returns: 영역 표시/경로/감쇠/상한 행을 담은 뷰입니다.
    private var contributionSection: some View {
        VStack(spacing: 10) {
            ForEach(explanation.contributionRows) { row in
                detailRow(
                    title: row.title,
                    badge: row.value,
                    body: row.detail,
                    identifier: "walklist.detail.outcomeReport.contribution.\(row.id)"
                )
            }
        }
    }

    /// 섹션 토글 버튼을 공통 시각 구조로 렌더링합니다.
    /// - Parameters:
    ///   - title: 버튼 제목입니다.
    ///   - identifier: 접근성 식별자입니다.
    ///   - isExpanded: 현재 펼침 상태입니다.
    ///   - action: 토글 시 실행할 동작입니다.
    /// - Returns: 펼침 상태가 반영된 토글 버튼 뷰입니다.
    private func disclosureButton(
        title: String,
        identifier: String,
        isExpanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Spacer(minLength: 0)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appDynamicHex(light: 0xF8FAFC, dark: 0x1E293B))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityIdentifier(identifier)
    }

    /// 요약 섹션의 핵심 수치 한 줄을 렌더링합니다.
    /// - Parameters:
    ///   - title: 수치 제목입니다.
    ///   - value: 수치 값 문자열입니다.
    ///   - identifier: 접근성 식별자입니다.
    /// - Returns: 좌우 정렬된 수치 행 뷰입니다.
    private func summaryMetricRow(title: String, value: String, identifier: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .subheadline))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            Spacer(minLength: 12)
            Text(value)
                .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
        }
        .accessibilityIdentifier(identifier)
    }

    /// 배지와 본문이 있는 상세 행을 렌더링합니다.
    /// - Parameters:
    ///   - title: 행 제목입니다.
    ///   - badge: 오른쪽 배지 또는 값 텍스트입니다.
    ///   - body: 보조 설명입니다.
    ///   - identifier: 접근성 식별자입니다.
    /// - Returns: 상세 펼침 섹션에 사용할 공통 행 뷰입니다.
    private func detailRow(
        title: String,
        badge: String,
        body: String,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Text(title)
                    .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .subheadline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Spacer(minLength: 0)
                Text(badge)
                    .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.appInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appYellowPale.opacity(0.9))
                    .clipShape(Capsule())
            }
            Text(body)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier(identifier)
    }
}
