//
//  MapRenderBudgetProbeOverlayView.swift
//  dogArea
//
//  Created by Codex on 3/8/26.
//

import Foundation
import SwiftUI

struct MapRenderBudgetProbeOverlayView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                Text(MapRenderBudgetProbe.currentCountText())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.72))
                    .clipShape(Capsule())
                    .accessibilityIdentifier("map.debug.renderCount")
            }

            Button("reset") {
                MapRenderBudgetProbe.reset()
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.72))
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .accessibilityIdentifier("map.debug.renderCount.reset")
        }
        .padding(.top, 12)
        .padding(.leading, 12)
    }
}

enum MapRenderBudgetProbe {
    private static let lock = NSLock()
    private static var mapSubViewBodyCount: Int = 0

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITest.TrackMapRenderBudget")
    }

    /// 지도 루트 body 평가 카운터를 초기화합니다.
    static func resetIfNeeded() {
        guard isEnabled else { return }
        lock.lock()
        mapSubViewBodyCount = 0
        lock.unlock()
    }

    /// UI 테스트가 안정화 이후 구간만 다시 측정할 수 있도록 카운터를 즉시 초기화합니다.
    static func reset() {
        guard isEnabled else { return }
        lock.lock()
        mapSubViewBodyCount = 0
        lock.unlock()
    }

    /// 지도 루트 body 평가 횟수를 누적합니다.
    static func recordMapSubViewBodyEvaluationIfNeeded() {
        guard isEnabled else { return }
        lock.lock()
        mapSubViewBodyCount += 1
        lock.unlock()
    }

    /// 현재 누적된 지도 루트 body 평가 횟수를 문자열로 반환합니다.
    /// - Returns: UI 테스트 접근성에서 읽을 수 있는 평가 횟수 문자열입니다.
    static func currentCountText() -> String {
        lock.lock()
        let count = mapSubViewBodyCount
        lock.unlock()
        return "\(count)"
    }
}
