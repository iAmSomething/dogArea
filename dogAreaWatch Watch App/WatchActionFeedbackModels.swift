//
//  WatchActionFeedbackModels.swift
//  dogAreaWatch Watch App
//
//  Created by Codex on 3/8/26.
//

import Foundation
import SwiftUI

enum WatchActionFeedbackTone: String, Equatable {
    case neutral
    case success
    case warning
    case failure
    case processing
}

enum WatchActionExecutionState: Equatable {
    case idle
    case processing
    case queued
    case acknowledged
    case completed
    case duplicateSuppressed
    case failed
    case confirmRequired
}

struct WatchActionFeedbackBanner: Equatable {
    let title: String
    let detail: String
    let tone: WatchActionFeedbackTone
}

struct WatchActionControlPresentation: Equatable {
    let title: String
    let detail: String
    let tone: WatchActionFeedbackTone
    let isDisabled: Bool
    let showsProgress: Bool
}

extension WatchActionFeedbackTone {
    var symbolName: String {
        switch self {
        case .neutral:
            return "info.circle"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .failure:
            return "xmark.octagon.fill"
        case .processing:
            return "arrow.triangle.2.circlepath.circle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .neutral:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .failure:
            return .red
        case .processing:
            return .yellow
        }
    }

    var backgroundColor: Color {
        tintColor.opacity(0.18)
    }
}

extension WatchActionType {
    var baseTitle: String {
        switch self {
        case .startWalk:
            return "산책 시작"
        case .addPoint:
            return "영역 표시하기"
        case .endWalk:
            return "산책 종료"
        case .syncState:
            return "상태 동기화"
        }
    }

    var processingTitle: String {
        switch self {
        case .startWalk:
            return "시작 요청 중"
        case .addPoint:
            return "영역 전송 중"
        case .endWalk:
            return "종료 요청 중"
        case .syncState:
            return "동기화 요청 중"
        }
    }

    var queuedTitle: String {
        switch self {
        case .startWalk:
            return "시작 큐 저장"
        case .addPoint:
            return "영역 큐 저장"
        case .endWalk:
            return "종료 큐 저장"
        case .syncState:
            return "동기화 큐 저장"
        }
    }

    var confirmationTitle: String {
        switch self {
        case .endWalk:
            return "한 번 더 탭"
        case .startWalk, .addPoint, .syncState:
            return baseTitle
        }
    }

    var duplicateSuppressedTitle: String {
        switch self {
        case .startWalk:
            return "시작 대기 중"
        case .addPoint:
            return "영역 중복 억제"
        case .endWalk:
            return "종료 대기 중"
        case .syncState:
            return "동기화 대기 중"
        }
    }

    var cooldownInterval: TimeInterval {
        switch self {
        case .startWalk, .endWalk:
            return 2.0
        case .addPoint:
            return 1.2
        case .syncState:
            return 0.0
        }
    }

    var confirmationWindow: TimeInterval {
        switch self {
        case .endWalk:
            return 3.0
        case .startWalk, .addPoint, .syncState:
            return 0.0
        }
    }

    var blocksWhileQueued: Bool {
        switch self {
        case .startWalk, .endWalk:
            return true
        case .addPoint, .syncState:
            return false
        }
    }

    var idleDetail: String {
        switch self {
        case .startWalk:
            return "탭 후 즉시 전송하거나 큐에 저장해요"
        case .addPoint:
            return "현재 위치를 1회 기록해요"
        case .endWalk:
            return "오조작 방지를 위해 한 번 더 확인해요"
        case .syncState:
            return "최신 상태를 다시 요청해요"
        }
    }
}
