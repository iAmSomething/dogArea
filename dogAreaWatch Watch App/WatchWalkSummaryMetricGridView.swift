import SwiftUI

struct WatchWalkSummaryMetricGridView: View {
    let elapsedTime: TimeInterval
    let area: Double
    let pointCount: Int
    let petName: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                metricTile(title: "시간", value: formattedTime(elapsedTime))
                metricTile(title: "넓이", value: formattedArea(area))
            }
            HStack(spacing: 8) {
                metricTile(title: "포인트", value: "\(pointCount)개")
                metricTile(title: "반려견", value: petName)
            }
        }
    }

    /// watch 요약 메트릭 한 칸을 렌더링합니다.
    /// - Parameters:
    ///   - title: 메트릭의 짧은 제목입니다.
    ///   - value: watch 폭에 맞춰 포맷된 값 문자열입니다.
    /// - Returns: 제목과 값을 함께 보여주는 요약 타일 뷰입니다.
    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    /// 누적 산책 시간을 watch 요약용 문자열로 변환합니다.
    /// - Parameter elapsedTime: 초 단위 누적 산책 시간입니다.
    /// - Returns: `mm:ss` 또는 `hh:mm:ss` 형태의 문자열입니다.
    private func formattedTime(_ elapsedTime: TimeInterval) -> String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        if hours == 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// 누적 영역 값을 watch 요약용 면적 문자열로 변환합니다.
    /// - Parameter area: 제곱미터 단위 누적 영역 값입니다.
    /// - Returns: watch 폭에 맞춘 축약 면적 문자열입니다.
    private func formattedArea(_ area: Double) -> String {
        if area >= 1_000_000 {
            return String(format: "%.2fkm²", area / 1_000_000)
        }
        if area >= 10_000 {
            return String(format: "%.2f만㎡", area / 10_000)
        }
        return String(format: "%.1f㎡", area)
    }
}
