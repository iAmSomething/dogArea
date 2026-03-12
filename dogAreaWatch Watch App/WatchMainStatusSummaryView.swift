import SwiftUI

struct WatchMainStatusSummaryView: View {
    let isWalking: Bool
    let isReachable: Bool
    let walkingTime: TimeInterval
    let pointCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isWalking ? "지금 산책 중입니다" : "산책을 시작할 수 있습니다")
                        .font(.headline.weight(.semibold))
                    Text(summarySubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                Text(isReachable ? "실시간 연결" : "오프라인 큐")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isReachable ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill((isReachable ? Color.green : Color.orange).opacity(0.18))
                    )
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    metricColumn(
                        title: "시간",
                        value: formatTime(walkingTime)
                    )
                    metricDivider
                    metricColumn(
                        title: "포인트",
                        value: "\(pointCount)개"
                    )
                    metricDivider
                    metricColumn(
                        title: "연결",
                        value: isReachable ? "바로 전송" : "큐 저장"
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .accessibilityIdentifier("watch.main.statusSummary.metrics")

                VStack(alignment: .leading, spacing: 6) {
                    metricRow(
                        title: "시간",
                        value: formatTime(walkingTime)
                    )
                    metricRow(
                        title: "포인트",
                        value: "\(pointCount)개"
                    )
                    metricRow(
                        title: "연결",
                        value: isReachable ? "바로 전송" : "큐 저장"
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .accessibilityIdentifier("watch.main.statusSummary.metrics")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("watch.main.statusSummary")
    }

    /// control surface에 노출할 현재 산책 요약 문구를 반환합니다.
    /// - Returns: 반려견 문맥과 산책 진행 상태를 반영한 짧은 안내 문구입니다.
    private var summarySubtitle: String {
        if isWalking {
            return "시간, 포인트, 연결 상태만 짧게 보여 줍니다."
        }
        return "반려견 문맥과 큐 상태는 옆 정보 화면에서 확인합니다."
    }

    /// 상단 요약 메트릭 한 칸을 수평 스트립용 컬럼으로 렌더링합니다.
    /// - Parameters:
    ///   - title: 메트릭의 짧은 제목입니다.
    ///   - value: watch 폭에 맞춰 포맷된 값 문자열입니다.
    /// - Returns: 제목과 값을 담은 요약 컬럼 뷰입니다.
    private func metricColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 상단 요약 메트릭 한 줄을 세로 fallback 레이아웃으로 렌더링합니다.
    /// - Parameters:
    ///   - title: 메트릭의 짧은 제목입니다.
    ///   - value: watch 폭에 맞춰 포맷된 값 문자열입니다.
    /// - Returns: 제목과 값을 양 끝 정렬한 메트릭 행 뷰입니다.
    private func metricRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 28)
    }

    /// 누적 산책 시간을 watch 화면용 문자열로 포맷합니다.
    /// - Parameter time: 초 단위 누적 산책 시간입니다.
    /// - Returns: `mm:ss` 또는 `hh:mm:ss` 형태의 표시 문자열입니다.
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        if hours == 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
