import Foundation

protocol WalkValueGuideStateStoring {
    /// 산책 가치 설명 가이드의 최초 자동 노출을 이미 소비했는지 반환합니다.
    /// - Returns: 최초 자동 노출을 본 적이 있으면 `true`, 아니면 `false`입니다.
    func hasPresentedInitialGuide() -> Bool
    /// 산책 가치 설명 가이드의 최초 자동 노출을 소비한 것으로 기록합니다.
    func markInitialGuidePresented()
}

final class DefaultWalkValueGuideStateStore: WalkValueGuideStateStoring {
    static let shared = DefaultWalkValueGuideStateStore()

    private let preferenceStore: MapPreferenceStoreProtocol
    private let initialPresentationKey = "walk.value.guide.initial.presented.v1"

    /// 산책 가치 설명 가이드 상태 저장소를 초기화합니다.
    /// - Parameter preferenceStore: 가이드 노출 여부를 영속화할 설정 저장소입니다.
    init(preferenceStore: MapPreferenceStoreProtocol = DefaultMapPreferenceStore.shared) {
        self.preferenceStore = preferenceStore
    }

    /// 산책 가치 설명 가이드의 최초 자동 노출을 이미 소비했는지 반환합니다.
    /// - Returns: 최초 자동 노출을 본 적이 있으면 `true`, 아니면 `false`입니다.
    func hasPresentedInitialGuide() -> Bool {
        preferenceStore.bool(forKey: initialPresentationKey, default: false)
    }

    /// 산책 가치 설명 가이드의 최초 자동 노출을 소비한 것으로 기록합니다.
    func markInitialGuidePresented() {
        preferenceStore.set(true, forKey: initialPresentationKey)
    }
}
