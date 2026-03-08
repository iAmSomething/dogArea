//
//  MapClusterMotionState.swift
//  dogArea
//
//  Created by Codex on 3/8/26.
//

import Foundation
import Combine

/// 클러스터 머지/분해 시각 효과만 별도 계층에서 구독하도록 분리한 상태 저장소입니다.
final class MapClusterMotionState: ObservableObject {
    @Published private(set) var transition: MapViewModel.ClusterMotionTransition = .none
    @Published private(set) var token: Int = 0

    /// 새 클러스터 모션 이벤트를 발행합니다.
    /// - Parameter transition: 이번에 실행할 클러스터 모션 전환 유형입니다.
    func trigger(_ transition: MapViewModel.ClusterMotionTransition) {
        self.transition = transition
        token += 1
    }

    /// 현재 클러스터 모션 상태를 유휴 상태로 되돌립니다.
    func reset() {
        transition = .none
    }
}
