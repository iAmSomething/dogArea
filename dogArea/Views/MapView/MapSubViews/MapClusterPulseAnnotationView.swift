//
//  MapClusterPulseAnnotationView.swift
//  dogArea
//
//  Created by Codex on 3/8/26.
//

import SwiftUI

struct MapClusterPulseAnnotationView: View {
    let count: Int
    let isReducedMotion: Bool
    let animationDuration: Double
    @ObservedObject var motionState: MapClusterMotionState
    let onTap: () -> Void

    @State private var isPulseActive: Bool = false

    var body: some View {
        VStack {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 24, height: 24)
                .background(Color.appGreen)
                .cornerRadius(10)
                .shadow(radius: 5)
            if count > 1 {
                Text("\(count)")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundColor(.appTextDarkGray)
            }
        }
        .scaleEffect(pulseScale)
        .opacity(pulseOpacity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onChange(of: motionState.token) {
            runPulseAnimationIfNeeded()
        }
    }

    /// 현재 모션 상태에 맞춰 클러스터 pulse 애니메이션을 실행합니다.
    private func runPulseAnimationIfNeeded() {
        guard motionState.transition != .none else { return }
        withAnimation(.easeOut(duration: animationDuration)) {
            isPulseActive = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            withAnimation(.easeOut(duration: animationDuration)) {
                isPulseActive = false
            }
        }
    }

    /// 현재 모션 상태에 대응하는 scale 값을 계산합니다.
    /// - Returns: merge/decompose 방향이 반영된 클러스터 scale 값입니다.
    private var pulseScale: Double {
        guard isPulseActive else { return 1.0 }
        switch motionState.transition {
        case .decompose:
            return 0.92
        case .merge:
            return 1.08
        case .none:
            return 1.0
        }
    }

    /// 현재 모션 상태에 대응하는 opacity 값을 계산합니다.
    /// - Returns: reduced motion 여부가 반영된 클러스터 opacity 값입니다.
    private var pulseOpacity: Double {
        guard isPulseActive else { return 1.0 }
        return isReducedMotion ? 0.92 : 0.82
    }
}
