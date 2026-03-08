//
//  WatchSelectedPetContextState.swift
//  dogAreaWatch Watch App
//
//  Created by Codex on 3/8/26.
//

import Foundation

enum WatchSelectedPetContextSource: String, Equatable {
    case selectedPet = "selected_pet"
    case fallbackActivePet = "fallback_active_pet"
    case walkingLocked = "walking_locked"
    case noActivePet = "no_active_pet"
}

struct WatchSelectedPetContextState: Equatable {
    let petId: String?
    let petName: String
    let source: WatchSelectedPetContextSource
    let badgeTitle: String
    let detail: String
    let isReadOnly: Bool
    let blocksInlineStart: Bool
    let lastSyncAt: TimeInterval?

    var tone: WatchActionFeedbackTone {
        switch source {
        case .selectedPet:
            return .neutral
        case .fallbackActivePet:
            return .warning
        case .walkingLocked:
            return .success
        case .noActivePet:
            return .failure
        }
    }

    var note: String {
        switch source {
        case .selectedPet:
            return "반려견 변경은 iPhone 앱에서 해 주세요."
        case .fallbackActivePet:
            return "iPhone 선택 상태와 다르면 다시 동기화해 주세요."
        case .walkingLocked:
            return "산책이 끝날 때까지 이 반려견으로 유지돼요."
        case .noActivePet:
            return "watch에서는 바로 시작하지 않고 앱 확인이 필요해요."
        }
    }

    var startBlockedDetail: String {
        detail.isEmpty ? "활성 반려견을 찾지 못했어요. iPhone 앱에서 먼저 확인해 주세요." : detail
    }

    /// 현재 문맥 카드에 다시 확인 버튼을 노출해야 하는지 계산합니다.
    /// - Parameter isReachable: iPhone과 즉시 통신 가능한 상태인지 여부입니다.
    /// - Returns: 문맥 재확인이 필요하면 `true`, 그렇지 않으면 `false`입니다.
    func showsRefreshAction(isReachable: Bool) -> Bool {
        if isReachable == false {
            return true
        }
        switch source {
        case .fallbackActivePet, .noActivePet:
            return true
        case .selectedPet, .walkingLocked:
            return false
        }
    }

    /// application context payload를 watch 선택 반려견 상태로 변환합니다.
    /// - Parameters:
    ///   - context: iPhone 앱이 전달한 최신 WatchConnectivity application context입니다.
    ///   - fallbackIsWalking: 레거시 payload일 때 산책 중 잠금 상태를 복원하기 위한 산책 진행 여부입니다.
    ///   - fallbackLastSyncAt: payload에 반려견 문맥 시각이 없을 때 사용할 마지막 동기화 시각입니다.
    /// - Returns: watch 화면이 바로 렌더링할 수 있는 선택 반려견 문맥 상태입니다.
    static func make(
        from context: [String: Any],
        fallbackIsWalking: Bool,
        fallbackLastSyncAt: TimeInterval?
    ) -> WatchSelectedPetContextState {
        guard let payload = context["selected_pet_context"] as? [String: Any] else {
            return legacyFallback(isWalking: fallbackIsWalking, lastSyncAt: fallbackLastSyncAt)
        }

        let rawSource = (payload["source"] as? String) ?? WatchSelectedPetContextSource.selectedPet.rawValue
        let source = WatchSelectedPetContextSource(rawValue: rawSource) ?? .selectedPet
        let detail = (payload["detail"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return WatchSelectedPetContextState(
            petId: (payload["pet_id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            petName: ((payload["pet_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "반려견",
            source: source,
            badgeTitle: ((payload["badge_title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? source.defaultBadgeTitle,
            detail: detail.isEmpty ? source.defaultDetail : detail,
            isReadOnly: (payload["is_read_only"] as? Bool) ?? true,
            blocksInlineStart: (payload["blocks_inline_start"] as? Bool) ?? (source == .noActivePet),
            lastSyncAt: (payload["last_sync_at"] as? TimeInterval) ?? fallbackLastSyncAt
        )
    }

    /// 레거시 watch context를 기본 반려견 문맥 상태로 복원합니다.
    /// - Parameters:
    ///   - isWalking: 현재 산책이 진행 중이면 `true`입니다.
    ///   - lastSyncAt: 마지막 상태 동기화 시각입니다.
    /// - Returns: 반려견 세부 payload가 없는 구버전 context를 위한 기본 상태입니다.
    static func legacyFallback(isWalking: Bool, lastSyncAt: TimeInterval?) -> WatchSelectedPetContextState {
        let source: WatchSelectedPetContextSource = isWalking ? .walkingLocked : .selectedPet
        return WatchSelectedPetContextState(
            petId: nil,
            petName: "반려견",
            source: source,
            badgeTitle: source.defaultBadgeTitle,
            detail: source.defaultDetail,
            isReadOnly: true,
            blocksInlineStart: false,
            lastSyncAt: lastSyncAt
        )
    }
}

private extension WatchSelectedPetContextSource {
    var defaultBadgeTitle: String {
        switch self {
        case .selectedPet:
            return "선택 반려견"
        case .fallbackActivePet:
            return "자동 대체"
        case .walkingLocked:
            return "산책 고정"
        case .noActivePet:
            return "앱 확인"
        }
    }

    var defaultDetail: String {
        switch self {
        case .selectedPet:
            return "iPhone에서 선택한 반려견으로 산책을 시작해요."
        case .fallbackActivePet:
            return "선택 반려견을 찾지 못해 활성 반려견으로 조정했어요."
        case .walkingLocked:
            return "산책 시작 시 확정된 반려견을 유지해요."
        case .noActivePet:
            return "활성 반려견이 없어 앱에서 먼저 확인이 필요해요."
        }
    }
}
