import Foundation

protocol SeasonGuideStateStoring {
    /// 시즌 가이드의 최초 자동 노출을 이미 소비했는지 반환합니다.
    /// - Returns: 최초 자동 노출을 이미 본 적이 있으면 `true`, 아니면 `false`입니다.
    func hasPresentedInitialSeasonGuide() -> Bool
    /// 시즌 가이드의 최초 자동 노출을 소비한 것으로 기록합니다.
    func markInitialSeasonGuidePresented()
}

final class DefaultSeasonGuideStateStore: SeasonGuideStateStoring {
    static let shared = DefaultSeasonGuideStateStore()

    private let preferenceStore: MapPreferenceStoreProtocol
    private let initialPresentationKey = "season.guide.initial.presented.v1"

    init(preferenceStore: MapPreferenceStoreProtocol = DefaultMapPreferenceStore.shared) {
        self.preferenceStore = preferenceStore
    }

    /// 시즌 가이드의 최초 자동 노출을 이미 소비했는지 반환합니다.
    /// - Returns: 최초 자동 노출을 이미 본 적이 있으면 `true`, 아니면 `false`입니다.
    func hasPresentedInitialSeasonGuide() -> Bool {
        preferenceStore.bool(forKey: initialPresentationKey, default: false)
    }

    /// 시즌 가이드의 최초 자동 노출을 소비한 것으로 기록합니다.
    func markInitialSeasonGuidePresented() {
        preferenceStore.set(true, forKey: initialPresentationKey)
    }
}
