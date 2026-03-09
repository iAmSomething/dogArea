import SwiftUI

struct WalkListMonthlyCalendarCardView: View {
    let model: WalkListCalendarPresentationModel
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onSelectDate: (Date) -> Void
    let onClearSelection: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("월별 산책 캘린더")
                        .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    Text(model.monthTitle)
                        .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .subheadline))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        .accessibilityIdentifier("walklist.calendar.month")
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    calendarNavigationButton(
                        systemName: "chevron.left",
                        accessibilityIdentifier: "walklist.calendar.previousMonth",
                        action: onPreviousMonth
                    )
                    calendarNavigationButton(
                        systemName: "chevron.right",
                        accessibilityIdentifier: "walklist.calendar.nextMonth",
                        action: onNextMonth
                    )
                }
            }

            if let selectionSummary = model.selectionSummary {
                HStack(alignment: .top, spacing: 10) {
                    Text(selectionSummary)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .subheadline))
                        .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFEF3C7))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("walklist.calendar.selection")

                    Spacer(minLength: 0)

                    if let clearSelectionTitle = model.clearSelectionTitle {
                        Button(clearSelectionTitle, action: onClearSelection)
                            .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("walklist.calendar.clear")
                    }
                }
            }

            if model.isEmptyState {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.appDynamicHex(light: 0xF59E0B, dark: 0xEAB308))
                    if let emptyTitle = model.emptyTitle {
                        Text(emptyTitle)
                            .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                            .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    }
                    if let emptyMessage = model.emptyMessage {
                        Text(emptyMessage)
                            .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x3F2A12).opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityIdentifier("walklist.calendar.empty")
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    ForEach(model.weekdayHeaders) { weekdayHeader in
                        weekdayHeaderView(for: weekdayHeader)
                    }

                    ForEach(model.dayCells) { dayCell in
                        WalkListMonthlyCalendarDayCellView(model: dayCell, onSelect: onSelectDate)
                    }
                }
            }

            Text(model.helperMessage)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)
        }
        .appCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walklist.calendar.card")
    }

    /// 주말/공휴일 semantic tone에 맞춰 요일 헤더 색을 반환합니다.
    /// - Parameter tone: 헤더가 따라야 할 의미 색상 tone입니다.
    /// - Returns: 현재 디자인 시스템에 맞는 헤더 전경색입니다.
    private func weekdayHeaderColor(for tone: WalkListCalendarSemanticTone) -> Color {
        switch tone {
        case .holiday, .sunday:
            return Color.appDynamicHex(light: 0xDC2626, dark: 0xFCA5A5)
        case .saturday:
            return Color.appDynamicHex(light: 0x2563EB, dark: 0x93C5FD)
        case .weekday:
            return Color.appDynamicHex(light: 0x94A3B8, dark: 0x94A3B8)
        }
    }

    /// 월별 캘린더 요일 헤더를 개별 접근성 요소로 승격해 semantic 색과 라벨을 함께 제공합니다.
    /// - Parameter weekdayHeader: 렌더링할 요일 헤더 모델입니다.
    /// - Returns: 주말/공휴일 semantic과 접근성 식별자가 반영된 헤더 뷰입니다.
    private func weekdayHeaderView(for weekdayHeader: WalkListCalendarWeekdayHeaderModel) -> some View {
        VStack(spacing: 0) {
            Text(weekdayHeader.symbol)
                .font(.appScaledFont(for: .SemiBold, size: 11, relativeTo: .caption))
                .foregroundStyle(weekdayHeaderColor(for: weekdayHeader.tone))
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(weekdayHeader.accessibilityIdentifier)
        .accessibilityLabel(weekdayHeader.accessibilityLabel)
    }

    /// 월 이동 버튼을 현재 제품 카드 스타일에 맞는 보조 CTA로 생성합니다.
    /// - Parameters:
    ///   - systemName: 표시할 SF Symbol 이름입니다.
    ///   - accessibilityIdentifier: UI 테스트와 접근성에 사용할 식별자입니다.
    ///   - action: 버튼 탭 시 실행할 동작입니다.
    /// - Returns: 월 이동 affordance가 반영된 버튼 뷰입니다.
    private func calendarNavigationButton(
        systemName: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                .frame(width: 44, height: 44)
                .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
