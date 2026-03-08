//
//  WatchActionHapticService.swift
//  dogAreaWatch Watch App
//
//  Created by Codex on 3/8/26.
//

import WatchKit

protocol WatchActionHapticServicing {
    /// 피드백 톤에 맞는 워치 햅틱을 재생합니다.
    /// - Parameter tone: 현재 사용자 피드백에 대응하는 톤 값입니다.
    func playFeedback(for tone: WatchActionFeedbackTone)
}

struct DefaultWatchActionHapticService: WatchActionHapticServicing {
    /// 피드백 톤에 맞는 워치 햅틱을 재생합니다.
    /// - Parameter tone: 현재 사용자 피드백에 대응하는 톤 값입니다.
    func playFeedback(for tone: WatchActionFeedbackTone) {
        guard let hapticType = tone.hapticType else { return }
        WKInterfaceDevice.current().play(hapticType)
    }
}

private extension WatchActionFeedbackTone {
    var hapticType: WKHapticType? {
        switch self {
        case .success:
            return .success
        case .warning:
            return .notification
        case .failure:
            return .failure
        case .neutral, .processing:
            return nil
        }
    }
}
