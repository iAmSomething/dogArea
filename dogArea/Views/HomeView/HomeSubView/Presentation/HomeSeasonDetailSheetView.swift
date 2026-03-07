import SwiftUI

struct HomeSeasonDetailSheetView: View {
    let summary: SeasonMotionSummary
    let remainingTimeText: String
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("현재 시즌")
                            .font(.appFont(for: .SemiBold, size: 16))
                        Text("주차 \(summary.weekKey.isEmpty ? "-" : summary.weekKey)")
                            .font(.appFont(for: .Light, size: 12))
                            .foregroundStyle(Color.appTextDarkGray)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        seasonDetailLine(title: "현재 티어", value: summary.rankTier.title)
                        seasonDetailLine(title: "누적 점수", value: "\(Int(summary.score.rounded()))점")
                        seasonDetailLine(title: "오늘 증가", value: "+\(summary.todayScoreDelta)점")
                        seasonDetailLine(title: "기여 횟수", value: "\(summary.contributionCount)회")
                        seasonDetailLine(title: "보호 적용", value: "\(summary.weatherShieldApplyCount)회")
                        seasonDetailLine(title: "남은 시간", value: remainingTimeText)
                    }
                    .padding(12)
                    .background(Color.appYellowPale.opacity(0.42))
                    .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("랭크 구간")
                            .font(.appFont(for: .SemiBold, size: 13))
                        ForEach(SeasonRankTier.allCases, id: \.rawValue) { tier in
                            HStack {
                                Text(tier.title)
                                    .font(.appFont(for: .Regular, size: 12))
                                Spacer()
                                Text("\(Int(tier.minimumScore))점+")
                                    .font(.appFont(for: .Light, size: 12))
                                    .foregroundStyle(Color.appTextDarkGray)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(summary.rankTier == tier ? Color.appYellowPale : Color.appTextLightGray.opacity(0.18))
                            .cornerRadius(8)
                        }
                    }

                    Text("점수는 미션 완료/기여 기준으로 누적되며, 결과는 시즌 종료 후 결과 모달에서 다시 확인할 수 있습니다.")
                        .font(.appFont(for: .Light, size: 11))
                        .foregroundStyle(Color.appTextDarkGray)
                }
                .padding(16)
            }
            .navigationTitle("시즌 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        onClose()
                    }
                    .accessibilityIdentifier("home.season.detail.close")
                }
            }
        }
    }

    /// 시즌 상세 시트의 키-값 한 줄을 구성합니다.
    /// - Parameters:
    ///   - title: 왼쪽 라벨 제목입니다.
    ///   - value: 오른쪽 강조 값입니다.
    /// - Returns: 시즌 상세 시트에서 재사용되는 한 줄 요약 뷰입니다.
    private func seasonDetailLine(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.appFont(for: .Light, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            Spacer()
            Text(value)
                .font(.appFont(for: .SemiBold, size: 13))
        }
    }
}
