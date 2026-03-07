import SwiftUI

struct WidgetStatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }
}

enum WidgetFormatting {
    /// 경과 시간을 `HH:MM:SS` 형식으로 변환합니다.
    /// - Parameter elapsedSeconds: 변환할 경과 시간(초)입니다.
    /// - Returns: 위젯 표시용 시간 문자열입니다.
    static func formattedElapsed(_ elapsedSeconds: Int) -> String {
        let total = max(0, elapsedSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// 유닉스 타임스탬프를 위젯 표시용 `HH:mm` 문자열로 변환합니다.
    /// - Parameter timestamp: 변환할 유닉스 초 단위 타임스탬프입니다.
    /// - Returns: 사용자 로캘 기준의 시:분 문자열입니다.
    static func formattedTime(timestamp: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("HHmm")
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }

    /// 제곱미터 면적을 위젯 표시용 문자열로 변환합니다.
    /// - Parameter areaM2: 변환할 원본 면적(`m²`)입니다.
    /// - Returns: `㎡ / 만 ㎡ / k㎡` 규칙이 반영된 위젯 표시 문자열입니다.
    static func formattedArea(_ areaM2: Double) -> String {
        let area = max(0, areaM2)
        if area > 100_000 {
            return String(format: "%.2f", area / 1_000_000) + "k㎡"
        }
        if area > 10_000 {
            return String(format: "%.2f", area / 10_000) + "만 ㎡"
        }
        return String(format: "%.2f", area) + "㎡"
    }

    /// 진행률 비율을 위젯 표시용 백분율 문자열로 변환합니다.
    /// - Parameter ratio: `0...1` 범위로 정규화된 진행률입니다.
    /// - Returns: 퍼센트 단위가 포함된 위젯 표시 문자열입니다.
    static func formattedPercent(_ ratio: Double) -> String {
        let normalized = min(1.0, max(0.0, ratio))
        return "\(Int((normalized * 100).rounded()))%"
    }

    /// 퀘스트/행동 부족분 실수 값을 위젯 표시용 축약 문자열로 변환합니다.
    /// - Parameter value: 남은 진행량 실수 값입니다.
    /// - Returns: 정수면 정수로, 아니면 소수 첫째 자리까지 포함한 문자열입니다.
    static func formattedProgressDelta(_ value: Double) -> String {
        let clamped = max(0.0, value)
        if abs(clamped.rounded() - clamped) < 0.001 {
            return String(Int(clamped.rounded()))
        }
        return String(format: "%.1f", clamped)
    }
}
