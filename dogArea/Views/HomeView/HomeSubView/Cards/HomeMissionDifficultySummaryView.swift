import SwiftUI

struct HomeMissionDifficultySummaryView: View {
    let summary: IndoorMissionDifficultySummary
    let onActivateEasyDayMode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(summary.petName) 기준 난이도: \(summary.adjustmentDescription)")
                .font(.appFont(for: .SemiBold, size: 12))
            Text("연령 \(summary.ageBand.title) · 활동 \(summary.activityLevel.title) · 빈도 \(summary.walkFrequency.title)")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            ForEach(summary.reasons.prefix(2), id: \.self) { reason in
                Text("• \(reason)")
                    .font(.appFont(for: .Light, size: 10))
                    .foregroundStyle(Color.appTextDarkGray)
            }
            Text(summary.easyDayMessage)
                .font(.appFont(for: .Light, size: 10))
                .foregroundStyle(Color.appTextDarkGray)

            if summary.easyDayState == .available {
                Button("쉬운 날 모드 사용 (보상 -20%)", action: onActivateEasyDayMode)
                    .font(.appFont(for: .SemiBold, size: 11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appYellow)
                    .cornerRadius(8)
            } else if summary.easyDayState == .active {
                Text("오늘 쉬운 날 모드 적용됨")
                    .font(.appFont(for: .SemiBold, size: 11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appYellowPale)
                    .cornerRadius(8)
            }

            if summary.history.isEmpty == false {
                VStack(alignment: .leading, spacing: 4) {
                    Text("최근 난이도 히스토리")
                        .font(.appFont(for: .SemiBold, size: 11))
                    ForEach(Array(summary.history.prefix(3))) { history in
                        let deltaPercent = Int(((history.multiplier - 1.0) * 100).rounded())
                        let multiplierText = deltaPercent == 0
                            ? "기본"
                            : (deltaPercent > 0 ? "+\(deltaPercent)%" : "\(deltaPercent)%")
                        Text(
                            "\(history.dayKey) · \(multiplierText)\(history.easyDayApplied ? " · 쉬운 날" : "")"
                        )
                        .font(.appFont(for: .Light, size: 10))
                        .foregroundStyle(Color.appTextDarkGray)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.appYellowPale.opacity(0.45))
        .cornerRadius(8)
    }
}
