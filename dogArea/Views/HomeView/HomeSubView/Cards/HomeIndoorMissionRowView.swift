import SwiftUI

struct HomeIndoorMissionRowView: View {
    let presentation: HomeIndoorMissionRowPresentation
    let animatedProgress: Double
    let isQuestMotionReduced: Bool
    let showClaimPulse: Bool
    let showProgressPulse: Bool
    let onRecordAction: () -> Void
    let onFinalize: () -> Void
    let onAppearSync: () -> Void
    let onProgressSync: (Double) -> Void

    private var mission: IndoorMissionCardModel {
        presentation.mission
    }

    private var badgeColor: Color {
        switch presentation.lifecycleState {
        case .actionRequired:
            return Color.appTextLightGray.opacity(0.35)
        case .readyToFinalize:
            return Color.appYellowPale
        case .completed:
            return Color.appGreen.opacity(0.18)
        }
    }

    private var finalizeButtonColor: Color {
        switch presentation.lifecycleState {
        case .actionRequired:
            return Color.appTextLightGray
        case .readyToFinalize:
            return Color.appYellow
        case .completed:
            return Color.appGreen
        }
    }

    private var cardBackground: Color {
        presentation.lifecycleState == .completed
            ? Color.appGreen.opacity(0.09)
            : Color.appYellowPale.opacity(0.42)
    }

    private var showsActionButtons: Bool {
        presentation.lifecycleState != .completed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
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
                    }
                    HomeMissionTrackingBadgeView(
                        mode: presentation.trackingMode,
                        accessibilityIdentifier: "home.quest.row.\(mission.id).tracking"
                    )
                    Text(presentation.trackingSummaryText)
                        .font(.appFont(for: .Light, size: 11))
                        .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("home.quest.row.\(mission.id).trackingSummary")
                    Text(presentation.requirementText)
                        .font(.appFont(for: .Light, size: 12))
                        .foregroundStyle(Color.appTextDarkGray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(presentation.badgeText)
                    .font(.appFont(for: .SemiBold, size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(badgeColor)
                    .cornerRadius(8)
                    .accessibilityIdentifier("home.quest.row.\(mission.id).status")
            }

            HomeAnimatedQuestProgressBarView(
                progress: animatedProgress,
                isCompleted: mission.progress.isCompleted,
                showPulse: showProgressPulse,
                isMotionReduced: isQuestMotionReduced
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.progressText)
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
                if let remainingText = presentation.remainingText {
                    Text(remainingText)
                        .font(.appFont(for: .SemiBold, size: 11))
                        .foregroundStyle(Color.appInk)
                }
                Text(presentation.rewardFootnote)
                    .font(.appFont(for: .Light, size: 10))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            }

            if showsActionButtons {
                VStack(alignment: .leading, spacing: 6) {
                    Text(presentation.guideTitle)
                        .font(.appFont(for: .SemiBold, size: 11))
                        .foregroundStyle(Color.appTextDarkGray)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(presentation.guideItems.enumerated()), id: \.offset) { index, item in
                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(Color.appInk)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 5)
                                Text(item)
                                    .font(.appFont(for: .Light, size: 11))
                                    .foregroundStyle(Color.appTextDarkGray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityIdentifier("home.quest.row.\(mission.id).guide.\(index)")
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.7))
                .cornerRadius(10)
            }

            Text(presentation.lifecycleMessage)
                .font(.appFont(for: .SemiBold, size: 11))
                .foregroundStyle(presentation.lifecycleState == .completed ? Color.appGreen : Color.appTextDarkGray)
                .accessibilityIdentifier("home.quest.row.\(mission.id).lifecycle")

            if showsActionButtons {
                HStack(spacing: 8) {
                    Button(action: onRecordAction) {
                        Text(presentation.recordActionTitle)
                            .font(.appFont(for: .SemiBold, size: 11))
                            .frame(minHeight: 44)
                            .padding(.horizontal, 10)
                    }
                        .background(Color.appYellowPale)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(presentation.recordActionTitle)
                        .accessibilityIdentifier("home.quest.action.record.\(mission.id)")

                    Button(action: onFinalize) {
                        Text(presentation.finalizeActionTitle)
                            .font(.appFont(for: .SemiBold, size: 11))
                            .frame(minHeight: 44)
                            .padding(.horizontal, 10)
                    }
                        .background(finalizeButtonColor)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                        .scaleEffect(showClaimPulse ? 1.06 : 1.0)
                        .animation(
                            isQuestMotionReduced ? nil : .spring(response: 0.3, dampingFraction: 0.74),
                            value: showClaimPulse
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(presentation.finalizeActionTitle)
                        .accessibilityIdentifier("home.quest.action.finalize.\(mission.id)")
                }
            }
        }
        .padding(12)
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    presentation.lifecycleState == .completed
                        ? Color.appGreen.opacity(0.24)
                        : Color.appTextLightGray.opacity(0.55),
                    lineWidth: 0.6
                )
        )
        .onAppear(perform: onAppearSync)
        .onChange(of: mission.progress.progressRatio) { _, next in
            onProgressSync(next)
        }
        .accessibilityIdentifier("home.quest.row.\(mission.id)")
    }
}
