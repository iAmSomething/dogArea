import SwiftUI

struct WatchMainStatusSummaryView: View {
    let isWalking: Bool
    let isReachable: Bool
    let walkingTime: TimeInterval
    let walkingArea: Double
    let pointCount: Int
    let petName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isWalking ? "산책 조작" : "산책 시작")
                        .font(.headline.weight(.semibold))
                    Text(summarySubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
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

            HStack(spacing: 6) {
                metricTile(
                    title: "시간",
                    value: formatTime(walkingTime)
                )
                metricTile(
                    title: "포인트",
                    value: "\(pointCount)개"
                )
                metricTile(
                    title: "연결",
                    value: isReachable ? "바로 전송" : "큐 저장"
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("watch.main.statusSummary")
    }

    /// control surface에 노출할 현재 산책 요약 문구를 반환합니다.
    /// - Returns: 반려견 문맥과 산책 진행 상태를 반영한 짧은 안내 문구입니다.
    private var summarySubtitle: String {
        let resolvedPetName = petName.isEmpty ? "반려견" : petName
        if isWalking {
            return "\(resolvedPetName)와 산책을 이어가며 포인트와 종료를 바로 조작할 수 있어요."
        }
        return "\(resolvedPetName) 기준으로 바로 산책을 시작할 수 있어요."
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
}
