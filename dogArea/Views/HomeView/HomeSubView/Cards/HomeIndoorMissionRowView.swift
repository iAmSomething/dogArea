import SwiftUI

struct HomeIndoorMissionRowView: View {
    let mission: IndoorMissionCardModel
    let animatedProgress: Double
    let isQuestMotionReduced: Bool
    let claimable: Bool
    let claimed: Bool
    let showClaimPulse: Bool
    let showProgressPulse: Bool
    let onRecordAction: () -> Void
    let onFinalize: () -> Void
    let onAppearSync: () -> Void
    let onProgressSync: (Double) -> Void

    private var folded: Bool {
        isQuestMotionReduced ? false : (claimable || claimed)
    }

    private var claimTitle: String {
        claimed ? "수령 완료" : (claimable ? "즉시 수령" : "완료 확인")
    }

    private var claimButtonColor: Color {
        claimed ? Color.appGreen : (claimable ? Color.appYellow : Color.appTextLightGray)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(mission.title)
                    .font(.appFont(for: .SemiBold, size: 14))
                if mission.isExtension {
                    Text("연장 슬롯")
                        .font(.appFont(for: .SemiBold, size: 10))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.appYellowPale)
                        .cornerRadius(6)
                }
                Spacer()
                Text("보상 \(mission.rewardPoint)pt")
                    .font(.appFont(for: .SemiBold, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
            }
            if folded == false {
                Text(mission.description)
                    .font(.appFont(for: .Light, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                if mission.isExtension {
                    Text("전일 미션 연장 · 보상 70% · 시즌 점수/연속 보상 제외")
                        .font(.appFont(for: .Light, size: 10))
                        .foregroundStyle(Color.appTextDarkGray)
                }
            }
            HomeAnimatedQuestProgressBarView(
                progress: animatedProgress,
                isCompleted: mission.progress.isCompleted,
                showPulse: showProgressPulse,
                isMotionReduced: isQuestMotionReduced
            )
            Text("행동량 \(mission.progress.actionCount)/\(mission.minimumActionCount)")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 8) {
                Button("행동 +1", action: onRecordAction)
                    .font(.appFont(for: .SemiBold, size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.appYellowPale)
                    .cornerRadius(8)
                    .disabled(claimed)

                Button(claimTitle, action: onFinalize)
                    .font(.appFont(for: .SemiBold, size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(claimButtonColor)
                    .cornerRadius(8)
                    .scaleEffect(showClaimPulse ? 1.06 : 1.0)
                    .animation(
                        isQuestMotionReduced ? nil : .spring(response: 0.3, dampingFraction: 0.74),
                        value: showClaimPulse
                    )
            }
        }
        .padding(10)
        .background(Color.appYellowPale.opacity(0.45))
        .cornerRadius(10)
        .scaleEffect(folded ? 0.985 : 1.0)
        .animation(isQuestMotionReduced ? nil : .easeInOut(duration: 0.22), value: folded)
        .onAppear(perform: onAppearSync)
        .onChange(of: mission.progress.progressRatio) { _, next in
            onProgressSync(next)
        }
        .accessibilityIdentifier("home.quest.row.\(mission.id)")
    }
}
