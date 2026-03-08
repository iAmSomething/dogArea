import Foundation

protocol HomeMissionGuideStateStoring {
    /// 홈 미션 도움말의 최초 자동 노출을 이미 소비했는지 반환합니다.
    /// - Returns: 최초 자동 노출을 본 적이 있으면 `true`, 아니면 `false`입니다.
    func hasPresentedInitialGuide() -> Bool
    /// 홈 미션 도움말의 최초 자동 노출을 소비한 것으로 기록합니다.
    func markInitialGuidePresented()
}

final class DefaultHomeMissionGuideStateStore: HomeMissionGuideStateStoring {
    static let shared = DefaultHomeMissionGuideStateStore()

    private let preferenceStore: MapPreferenceStoreProtocol
    private let initialPresentationKey = "home.mission.guide.initial.presented.v1"

    /// 홈 미션 도움말 상태 저장소를 초기화합니다.
    /// - Parameter preferenceStore: 도움말 최초 노출 여부를 영속화할 설정 저장소입니다.
    init(preferenceStore: MapPreferenceStoreProtocol = DefaultMapPreferenceStore.shared) {
        self.preferenceStore = preferenceStore
    }

    /// 홈 미션 도움말의 최초 자동 노출을 이미 소비했는지 반환합니다.
    /// - Returns: 최초 자동 노출을 본 적이 있으면 `true`, 아니면 `false`입니다.
    func hasPresentedInitialGuide() -> Bool {
        preferenceStore.bool(forKey: initialPresentationKey, default: false)
    }

    /// 홈 미션 도움말의 최초 자동 노출을 소비한 것으로 기록합니다.
    func markInitialGuidePresented() {
        preferenceStore.set(true, forKey: initialPresentationKey)
    }
}
