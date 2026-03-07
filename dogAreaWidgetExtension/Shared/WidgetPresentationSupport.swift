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
}
