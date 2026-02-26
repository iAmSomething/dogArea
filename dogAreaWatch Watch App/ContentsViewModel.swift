//
//  ContentsViewModel.swift
//  dogAreaWatch Watch App
//
//  Created by 김태훈 on 12/27/23.
//

import Foundation
import WatchConnectivity

final class ContentsViewModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isWalking = false
    @Published var walkTime: TimeInterval = 0
    @Published var walkArea: Double = 0
    @Published var statusText: String = "연결 대기 중"
    private let session = WCSession.isSupported() ? WCSession.default : nil

    override init() {
        super.init()
        if let session {
            session.delegate = self
            session.activate()
        } else {
            statusText = "지원되지 않는 기기"
        }
        applyContext(session?.receivedApplicationContext ?? [:])
    }

    func sendAction(_ action: String) {
        guard let session else { return }
        let payload: [String: Any] = ["action": action]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
            return
        }
        try? session.updateApplicationContext(payload)
    }

    private func applyContext(_ context: [String: Any]) {
        DispatchQueue.main.async {
            self.isWalking = (context["isWalking"] as? Bool) ?? false
            self.walkTime = (context["time"] as? TimeInterval) ?? 0
            self.walkArea = (context["area"] as? Double) ?? 0
            self.statusText = self.isWalking ? "산책 진행 중" : "산책 대기 중"
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        applyContext(applicationContext)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.statusText = session.isReachable ? "연결됨" : (self.isWalking ? "산책 진행 중" : "연결 대기 중")
        }
    }

    #if os(watchOS)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        DispatchQueue.main.async {
            if activationState == .activated {
                self.statusText = "연결됨"
            } else if let error {
                self.statusText = "연결 오류: \(error.localizedDescription)"
            }
        }
    }
    #endif
}
