import Foundation

@MainActor
final class MapViewModelStore: ObservableObject {
    @Published private(set) var mapViewModel: MapViewModel?

    /// 지도 탭 진입이나 위젯 액션 처리 직전에 지도 ViewModel을 지연 생성합니다.
    /// - Important: 이미 생성된 인스턴스가 있으면 재생성하지 않아 탭 전환 중 상태를 유지합니다.
    func prepareIfNeeded() {
        guard mapViewModel == nil else { return }
        mapViewModel = MapViewModel()
    }

    /// 위젯 산책 액션을 지도 ViewModel에 큐잉합니다.
    /// - Parameter route: 지도 런타임 준비 후 적용할 위젯 산책 액션입니다.
    func queueWidgetWalkAction(_ route: WalkWidgetActionRoute) {
        prepareIfNeeded()
        mapViewModel?.enqueueWidgetWalkAction(route)
    }

    /// 인증 오버레이가 보이는 동안 Metal 렌더 경합을 막기 위해 지도 ViewModel을 해제합니다.
    func suspendForAuthenticationOverlay() {
        mapViewModel = nil
    }
}
