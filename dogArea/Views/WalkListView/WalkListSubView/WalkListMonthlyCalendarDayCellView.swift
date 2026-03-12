import SwiftUI

struct WalkListMonthlyCalendarDayCellView: View {
    let model: WalkListCalendarDayCellModel
    let onSelect: (Date) -> Void

    var body: some View {
        Group {
            if let date = model.date {
                if model.isInteractive {
                    interactiveDayCell(for: date)
                } else {
                    staticDayCell
                }
            } else {
                Color.clear
                    .frame(height: 46)
                    .accessibilityHidden(true)
            }
        }
    }

    /// 선택 가능한 날짜 셀을 명시적인 접근성 버튼 요소로 렌더링합니다.
    /// - Parameter date: 사용자가 탭했을 때 전달할 날짜의 `startOfDay` 값입니다.
    /// - Returns: UI 테스트와 VoiceOver가 같은 식별자/라벨을 읽는 날짜 버튼 뷰입니다.
    private func interactiveDayCell(for date: Date) -> some View {
        Button {
            onSelect(date)
        } label: {
            cellBody
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(model.accessibilityIdentifier ?? "")
        .accessibilityLabel(model.accessibilityLabel)
    }

    /// 선택 불가능한 날짜 셀을 명시적인 정적 접근성 요소로 렌더링합니다.
    /// - Returns: UI 테스트와 VoiceOver가 직접 찾을 수 있는 날짜 셀 뷰입니다.
    private var staticDayCell: some View {
        cellBody
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(model.accessibilityIdentifier ?? "")
            .accessibilityLabel(model.accessibilityLabel)
    }

    private var cellBody: some View {
        VStack(spacing: 4) {
            Text(model.dayText)
                .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .callout))
                .foregroundStyle(dayTextColor)
                .frame(maxWidth: .infinity)

            indicatorView
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: model.isSelected || model.isToday ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(model.isCurrentMonth ? 1 : 0)
    }

    @ViewBuilder
    private var indicatorView: some View {
        if model.walkCount >= 2 {
            Text("\(model.walkCount)")
                .font(.appScaledFont(for: .SemiBold, size: 10, relativeTo: .caption2))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 6)
                .frame(minHeight: 18)
                .background(Color.appDynamicHex(light: 0xF59E0B, dark: 0xEAB308))
                .clipShape(Capsule())
        } else if model.walkCount == 1 {
            Circle()
                .fill(Color.appDynamicHex(light: 0x10B981, dark: 0x34D399))
                .frame(width: 8, height: 8)
        } else {
            Color.clear
                .frame(height: 18)
        }
    }

    private var backgroundColor: Color {
        if model.isSelected {
            return Color.appDynamicHex(light: 0xFEF3C7, dark: 0x78350F).opacity(0.92)
        }
        if model.isToday {
            return Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155).opacity(0.7)
        }
        return Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B).opacity(model.isInteractive ? 0.9 : 0.55)
    }

    private var borderColor: Color {
        if model.isSelected {
            return Color.appDynamicHex(light: 0xF59E0B, dark: 0xEAB308)
        }
        if model.isToday {
            return Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1)
        }
        return Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155)
    }

    private var dayTextColor: Color {
        switch model.semanticTone {
        case .holiday, .sunday:
            return model.isInteractive
                ? Color.appDynamicHex(light: 0xDC2626, dark: 0xFCA5A5)
                : Color.appDynamicHex(light: 0xF87171, dark: 0x991B1B)
        case .saturday:
            return model.isInteractive
                ? Color.appDynamicHex(light: 0x2563EB, dark: 0x93C5FD)
                : Color.appDynamicHex(light: 0x60A5FA, dark: 0x1D4ED8)
        case .weekday:
            if model.isInteractive {
                return Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC)
            }
            return Color.appDynamicHex(light: 0x94A3B8, dark: 0x64748B)
        }
    }
}
