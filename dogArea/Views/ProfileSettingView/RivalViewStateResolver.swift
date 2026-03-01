import Foundation

/// 라이벌 화면 상태 판정 입력값입니다.
struct RivalViewStateInput {
    let hasAuthenticatedUser: Bool
    let permissionState: RivalTabViewModel.PermissionState
    let locationSharingEnabled: Bool
    let hasHotspots: Bool
    let compareScope: RivalCompareScope
    let hasLeaderboardEntries: Bool
}

/// 라이벌 화면의 Screen/Leaderboard 상태를 계산하는 정책 객체입니다.
enum RivalViewStateResolver {
    /// 화면 상태를 입력값 기반으로 계산합니다.
    /// - Parameter input: 인증/권한/공유/데이터 보유 여부를 담은 입력값입니다.
    /// - Returns: 메인 카드 상태(`screen`)와 리더보드 상태(`leaderboard`)의 튜플입니다.
    static func resolve(_ input: RivalViewStateInput) -> (
        screen: RivalTabViewModel.ScreenState,
        leaderboard: RivalTabViewModel.LeaderboardState
    ) {
        guard input.hasAuthenticatedUser else {
            return (.guestLocked, .guestLocked)
        }
        guard input.permissionState == .authorized else {
            return (.permissionRequired, .permissionRequired)
        }
        guard input.locationSharingEnabled else {
            return (.consentRequired, .consentRequired)
        }

        let screen: RivalTabViewModel.ScreenState = input.hasHotspots ? .ready : .empty
        let leaderboard: RivalTabViewModel.LeaderboardState
        if input.compareScope == .friend {
            leaderboard = .friendPreview
        } else if input.hasLeaderboardEntries {
            leaderboard = .ready
        } else {
            leaderboard = .empty
        }
        return (screen, leaderboard)
    }
}
