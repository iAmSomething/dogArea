import SwiftUI

struct WatchMainStatusSummaryView: View {
    let isWalking: Bool
    let isReachable: Bool
    let walkingTime: TimeInterval
    let walkingArea: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isWalking ? "산책 중" : "대기 중")
                    .font(.headline.weight(.semibold))
                Text(isReachable ? "바로 전송 가능" : "오프라인 큐 모드")
                    .font(.caption2)
                    .foregroundStyle(isReachable ? .green : .orange)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                metricTile(
                    title: "시간",
                    value: formatTime(walkingTime)
                )
                metricTile(
                    title: "넓이",
                    value: formatArea(walkingArea)
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("watch.main.statusSummary")
    }

    /// 상단 요약 메트릭 한 칸을 렌더링합니다.
    /// - Parameters:
    ///   - title: 메트릭의 짧은 제목입니다.
    ///   - value: watch 폭에 맞춰 포맷된 값 문자열입니다.
    /// - Returns: 제목과 값을 담은 요약 타일 뷰입니다.
    private func metricTile(title: String, value: String) -> some View {
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
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
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

    /// 누적 산책 영역을 watch 화면용 문자열로 포맷합니다.
    /// - Parameter area: 제곱미터 단위 누적 영역 값입니다.
    /// - Returns: watch 폭에 맞춘 간단한 면적 문자열입니다.
    private func formatArea(_ area: Double) -> String {
        if area > 100000.0 {
            return String(format: "%.2fkm²", area / 1000000)
        }
        if area > 10000.0 {
            return String(format: "%.2f만㎡", area / 10000)
        }
        return String(format: "%.1f㎡", area)
    }
}
