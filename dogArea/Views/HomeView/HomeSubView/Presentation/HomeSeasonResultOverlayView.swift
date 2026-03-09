import SwiftUI

struct HomeSeasonResultOverlayView: View {
    let payload: SeasonResultPresentation
    let rewardStatus: SeasonRewardClaimStatus
    let revealRank: Bool
    let revealContribution: Bool
    let revealShield: Bool
    let isVisible: Bool
    let onDismiss: () -> Void
    let onRetryClaim: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("시즌 결과")
                            .font(.appFont(for: .SemiBold, size: 18))
                        Text("\(payload.weekKey) 리포트")
                            .font(.appFont(for: .Light, size: 12))
                            .foregroundStyle(Color.appTextDarkGray)
                    }
                    Spacer()
                    Button("닫기") {
                        onDismiss()
                    }
                    .font(.appFont(for: .SemiBold, size: 11))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appYellowPale)
                    .cornerRadius(8)
                }
                seasonResultRow(
                    title: "최종 랭크",
                    value: payload.rankTier.title,
                    isVisible: revealRank
                )
                seasonResultRow(
                    title: "기여 횟수",
                    value: "\(payload.contributionCount)회",
                    isVisible: revealContribution
                )
                seasonResultRow(
                    title: "보호 적용",
                    value: "\(payload.shieldApplyCount)회",
                    isVisible: revealShield
                )
                HStack {
                    Text("보상 상태")
                        .font(.appFont(for: .Light, size: 12))
                        .foregroundStyle(Color.appTextDarkGray)
                    Spacer()
                    Text(seasonRewardStatusText(rewardStatus))
                        .font(.appFont(for: .SemiBold, size: 13))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(seasonRewardStatusColor(rewardStatus).opacity(0.18))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.appYellowPale.opacity(0.45))
                .cornerRadius(8)
                if rewardStatus == .pending || rewardStatus == .failed {
                    HStack {
                        Spacer()
                        Button(rewardStatus == .failed ? "재수령" : "수령 처리") {
                            onRetryClaim()
                        }
                        .font(.appFont(for: .SemiBold, size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appYellow)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.appYellow, lineWidth: 1.0)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 72)
            .scaleEffect(isVisible ? 1.0 : 0.9)
            .opacity(isVisible ? 1.0 : 0.0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(isVisible ? 0.22 : 0.0))
    }

    /// 시즌 보상 상태를 사용자용 문자열로 변환합니다.
    /// - Parameter status: 시즌 보상 청구 상태입니다.
    /// - Returns: 결과 오버레이에 표시할 보상 상태 문구입니다.
    private func seasonRewardStatusText(_ status: SeasonRewardClaimStatus) -> String {
        switch status {
        case .pending:
            return "대기"
        case .claimed:
            return "수령 완료"
        case .failed:
            return "실패"
        case .unavailable:
            return "서버 확인 필요"
        }
    }

    /// 시즌 보상 상태에 대응하는 강조 색상을 계산합니다.
    /// - Parameter status: 시즌 보상 청구 상태입니다.
    /// - Returns: 상태 배지 배경에 사용할 색상입니다.
    private func seasonRewardStatusColor(_ status: SeasonRewardClaimStatus) -> Color {
        switch status {
        case .pending:
            return Color.appYellow
        case .claimed:
            return Color.appGreen
        case .failed:
            return Color.appRed
        case .unavailable:
            return Color.appTextDarkGray
        }
    }

    /// 시즌 결과 한 줄 요약을 표시합니다.
    /// - Parameters:
    ///   - title: 요약 항목 제목입니다.
    ///   - value: 요약 값입니다.
    ///   - isVisible: 등장 애니메이션 노출 여부입니다.
    /// - Returns: 결과 오버레이에서 재사용되는 요약 행 뷰입니다.
    private func seasonResultRow(title: String, value: String, isVisible: Bool) -> some View {
        HStack {
            Text(title)
                .font(.appFont(for: .Light, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            Spacer()
            Text(value)
                .font(.appFont(for: .SemiBold, size: 15))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.appYellowPale.opacity(0.45))
        .cornerRadius(8)
        .offset(y: isVisible ? 0 : 10)
        .opacity(isVisible ? 1.0 : 0.0)
    }
}
