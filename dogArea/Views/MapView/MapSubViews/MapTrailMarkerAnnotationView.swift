//
//  MapTrailMarkerAnnotationView.swift
//  dogArea
//
//  Created by Codex on 3/8/26.
//

import SwiftUI

struct MapTrailMarkerAnnotationView: View {
    private struct VisualState {
        let scale: Double
        let opacity: Double
    }

    let trail: MapViewModel.TrailMarker
    let isReducedMotion: Bool

    @State private var scale: Double = 1.0
    @State private var opacity: Double = 1.0

    var body: some View {
        Image(systemName: "pawprint.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.appInk.opacity(0.8))
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                startLifecycleAnimation()
            }
            .onChange(of: trail.recordedAt) {
                startLifecycleAnimation()
            }
    }

    /// 현재 trail age에 맞춰 초기 상태를 맞춘 뒤 남은 수명 구간만 애니메이션합니다.
    private func startLifecycleAnimation() {
        let initialState = makeVisualState(at: Date())
        scale = initialState.scale
        opacity = initialState.opacity

        let remainingDuration = max(0, lifetimeDuration - currentTrailAge)
        guard remainingDuration > 0 else { return }

        withAnimation(.linear(duration: adjustedRemainingDuration(for: remainingDuration))) {
            scale = 0.95
            opacity = 0.10
        }
    }

    /// 기준 시각에 맞춰 trail marker의 스케일/투명도 상태를 계산합니다.
    /// - Parameter now: 현재 렌더 기준 시각입니다.
    /// - Returns: 현재 시점에 적용할 trail marker 시각 상태입니다.
    private func makeVisualState(at now: Date) -> VisualState {
        let age = max(0, now.timeIntervalSince1970 - trail.recordedAt)
        let ratio = min(1.0, max(0.0, age / lifetimeDuration))
        return VisualState(
            scale: 0.95 + ((1.0 - ratio) * 0.25),
            opacity: 0.75 - (ratio * 0.65)
        )
    }

    /// 현재 trail age를 계산합니다.
    /// - Returns: trail이 생성된 이후 경과한 시간입니다.
    private var currentTrailAge: Double {
        max(0, Date().timeIntervalSince1970 - trail.recordedAt)
    }

    /// reduced motion 설정을 반영해 남은 애니메이션 시간을 보정합니다.
    /// - Parameter remainingDuration: 현재 시점 기준 남은 trail life 시간입니다.
    /// - Returns: 실제 애니메이션에 사용할 남은 시간입니다.
    private func adjustedRemainingDuration(for remainingDuration: Double) -> Double {
        isReducedMotion ? max(0.15, remainingDuration * 0.6) : remainingDuration
    }

    /// trail marker가 시각적으로 유지될 총 lifetime입니다.
    private var lifetimeDuration: Double {
        5.0
    }
}
