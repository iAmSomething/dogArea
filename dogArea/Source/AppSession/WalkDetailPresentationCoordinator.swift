import Foundation

@MainActor
final class WalkDetailPresentationCoordinator {
    static let shared = WalkDetailPresentationCoordinator()

    private var stagedModel: WalkDataModel? = nil

    private init() {}

    /// 저장 직후 산책 상세 화면을 열기 위해 다음 프레젠테이션 모델을 임시로 적재합니다.
    /// - Parameter model: 즉시 노출할 산책 상세 화면의 원본 모델입니다.
    func stage(model: WalkDataModel) {
        stagedModel = model
    }

    /// 적재된 산책 상세 프레젠테이션 모델을 한 번만 소비합니다.
    /// - Returns: 대기 중인 산책 상세 모델이 있으면 반환하고, 없으면 `nil`입니다.
    func consumeStagedRoute() -> WalkDataModel? {
        let stagedModel = stagedModel
        self.stagedModel = nil
        return stagedModel
    }

    /// 적재된 산책 상세 프레젠테이션 상태를 초기화합니다.
    func clear() {
        stagedModel = nil
    }
}
