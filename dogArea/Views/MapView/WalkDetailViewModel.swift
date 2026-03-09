import SwiftUI
import UIKit

/// 산책 상세 화면이 의존하는 데이터/액션 컨텍스트 인터페이스입니다.
protocol WalkDetailContextProviding: AnyObject {
    /// 현재 종료 대상 산책 생성 시각입니다.
    var walkCreatedAt: TimeInterval { get }
    /// 현재 종료 대상 산책 총 시간(초)입니다.
    var walkDuration: TimeInterval { get }
    /// 현재 종료 대상 산책 면적(m²)입니다.
    var walkAreaM2: Double { get }
    /// 현재 종료 대상 산책 포인트 개수입니다.
    var walkPointCount: Int { get }
    /// 현재 산책 반려견 이름입니다.
    var walkPetName: String { get }

    /// 면적 문자열을 단위 옵션에 맞춰 반환합니다.
    /// - Parameters:
    ///   - areaSize: 변환할 면적 값(m²)입니다.
    ///   - isPyong: 평 단위 사용 여부입니다.
    /// - Returns: 단위가 반영된 포맷 문자열입니다.
    func calculatedAreaString(areaSize: Double, isPyong: Bool) -> String

    /// 산책 종료 메시지를 노출합니다.
    /// - Parameter message: 사용자에게 보여줄 상태 메시지입니다.
    func setWalkStatusMessage(_ message: String)

    /// 산책을 종료하고 결과 이미지를 저장합니다.
    /// - Parameter image: 산책 결과 이미지입니다.
    func endWalk(with image: UIImage?)
}

@MainActor
final class WalkDetailViewModel: ObservableObject {
    @Published var isMeter: Bool = true
    @Published var capturedWalkPhoto: UIImage? = nil
    @Published var shareItems: [Any] = []
    @Published var showShareSheet: Bool = false
    @Published var showCameraPicker: Bool = false
    @Published var showPhotoLibraryPicker: Bool = false
    @Published var toastMessage: String? = nil
    @Published private(set) var isContextBound: Bool = false

    private weak var context: WalkDetailContextProviding?
    private let walkValueFlowPresentationService: MapWalkValueFlowPresenting

    /// 산책 상세 전용 뷰모델을 초기화합니다.
    /// - Parameter walkValueFlowPresentationService: 산책 종료 전후 가치 설명 카드 생성을 담당하는 서비스입니다.
    init(walkValueFlowPresentationService: MapWalkValueFlowPresenting = MapWalkValueFlowPresentationService()) {
        self.walkValueFlowPresentationService = walkValueFlowPresentationService
    }

    /// 외부 산책 컨텍스트를 연결합니다.
    /// - Parameter context: 산책 데이터/종료 액션을 제공하는 컨텍스트입니다.
    func bind(context: WalkDetailContextProviding) {
        self.context = context
        isContextBound = true
    }

    /// 공유/미리보기에서 사용할 우선 이미지를 계산합니다.
    /// - Parameter mapCapturedImage: 지도 스냅샷으로 캡처된 이미지입니다.
    /// - Returns: 사용자가 촬영한 이미지가 있으면 우선, 없으면 지도 이미지입니다.
    func previewImage(mapCapturedImage: UIImage?) -> UIImage? {
        capturedWalkPhoto ?? mapCapturedImage
    }

    /// 현재 선택 단위 기준 면적 문자열을 반환합니다.
    /// - Returns: 화면에 노출할 면적 텍스트입니다.
    func areaValueText() -> String {
        guard let context else { return "-" }
        return context.calculatedAreaString(areaSize: context.walkAreaM2, isPyong: !isMeter)
    }

    /// 현재 산책 시간 문자열을 반환합니다.
    /// - Returns: 화면에 노출할 산책 시간 텍스트입니다.
    func durationText() -> String {
        guard let context else { return "-" }
        return context.walkDuration.simpleWalkingTimeInterval
    }

    /// 산책 종료 확인 화면에 노출할 가치 설명 프레젠테이션을 생성합니다.
    /// - Returns: 저장 후 이어질 결과를 설명하는 프레젠테이션입니다. 컨텍스트가 없으면 `nil`입니다.
    func completionValuePresentation() -> WalkCompletionValuePresentation? {
        guard let context else { return nil }
        return walkValueFlowPresentationService.makeCompletionValuePresentation(
            petName: context.walkPetName,
            durationText: context.walkDuration.simpleWalkingTimeInterval,
            areaText: context.calculatedAreaString(areaSize: context.walkAreaM2, isPyong: !isMeter),
            pointCount: context.walkPointCount
        )
    }

    /// 면적 단위를 미터/평 기준으로 토글합니다.
    func toggleAreaUnit() {
        isMeter.toggle()
    }

    /// 카메라/앨범 입력 경로를 결정하고 화면 상태를 갱신합니다.
    /// - Returns: 없음. 필요한 모달 플래그와 토스트 메시지를 갱신합니다.
    func requestImageInput() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showCameraPicker = true
            return
        }
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            toastMessage = "카메라 미지원 환경이라 앨범 선택으로 전환했어요."
            showPhotoLibraryPicker = true
            return
        }
        toastMessage = "이미지 입력을 사용할 수 없는 환경입니다."
    }

    /// 공유 시트에 필요한 아이템을 구성해 표시합니다.
    /// - Parameter mapCapturedImage: 지도 스냅샷으로 캡처된 이미지입니다.
    func prepareShareSheet(mapCapturedImage: UIImage?) {
        shareItems = makeShareItems(mapCapturedImage: mapCapturedImage)
        guard shareItems.isEmpty == false else {
            toastMessage = "공유할 내용을 준비하지 못했습니다. 다시 시도해주세요."
            showShareSheet = false
            return
        }
        showShareSheet = true
    }

    /// 시스템 공유 presenter 결과를 사용자 피드백 메시지로 변환합니다.
    /// - Parameter result: 시스템 공유 presenter 종료 결과입니다.
    func handleSharePresentationResult(_ result: ActivitySharePresentationResult) {
        switch result {
        case .presented:
            break
        case .completed:
            toastMessage = "공유를 완료했습니다"
        case .cancelled:
            toastMessage = "공유를 취소했습니다"
        case .failed:
            toastMessage = "공유 시트를 열지 못했습니다. 다시 시도해주세요."
        }
    }

    /// 현재 산책 카드를 사진 앱에 저장합니다.
    /// - Parameters:
    ///   - mapCapturedImage: 지도 스냅샷으로 캡처된 이미지입니다.
    ///   - onLoading: 저장 시작 시 호출할 콜백입니다.
    ///   - onFailed: 저장 실패 시 호출할 콜백입니다.
    ///   - onSuccess: 저장 성공 시 호출할 콜백입니다.
    /// - Returns: 저장 성공 여부입니다.
    @discardableResult
    func saveShareCardToPhotoLibrary(
        mapCapturedImage: UIImage?,
        onLoading: () -> Void,
        onFailed: (String) -> Void,
        onSuccess: () -> Void
    ) -> Bool {
        onLoading()
        guard let image = buildShareCardImage(mapCapturedImage: mapCapturedImage) else {
            onFailed("이미지 가져오기 실패")
            return false
        }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        onSuccess()
        toastMessage = "저장이 완료되었습니다"
        return true
    }

    /// 산책 종료 확인 액션을 수행합니다.
    /// - Parameter mapCapturedImage: 지도 스냅샷으로 캡처된 이미지입니다.
    func confirmWalkEnd(mapCapturedImage: UIImage?) {
        guard let context else { return }
        if mapCapturedImage == nil {
            context.setWalkStatusMessage("지도 이미지 없이 산책 기록만 저장했습니다.")
        }
        context.endWalk(with: mapCapturedImage)
    }

    /// 토스트 메시지를 지웁니다.
    func clearToastMessage() {
        toastMessage = nil
    }

    /// 공유 카드에 사용할 최종 이미지를 생성합니다.
    /// - Parameter mapCapturedImage: 지도 스냅샷으로 캡처된 이미지입니다.
    /// - Returns: 공유 카드 이미지 생성 성공 시 `UIImage`, 실패 시 `nil`입니다.
    private func buildShareCardImage(mapCapturedImage: UIImage?) -> UIImage? {
        guard let context,
              let baseImage = previewImage(mapCapturedImage: mapCapturedImage) else { return nil }
        return WalkShareCardTemplateBuilder.build(
            baseImage: baseImage,
            createdAt: context.walkCreatedAt,
            duration: context.walkDuration,
            areaM2: context.walkAreaM2,
            pointCount: context.walkPointCount,
            petName: context.walkPetName
        )
    }

    /// 공유 시트용 아이템 배열(텍스트 요약 + 카드 이미지)을 구성합니다.
    /// - Parameter mapCapturedImage: 지도 스냅샷으로 캡처된 이미지입니다.
    /// - Returns: 공유 시트에 전달할 아이템 배열입니다.
    private func makeShareItems(mapCapturedImage: UIImage?) -> [Any] {
        guard let context else { return [] }
        let summary = WalkShareSummaryBuilder.build(
            createdAt: context.walkCreatedAt,
            duration: context.walkDuration,
            areaM2: context.walkAreaM2,
            pointCount: context.walkPointCount,
            petName: context.walkPetName
        )
        if let shareCard = buildShareCardImage(mapCapturedImage: mapCapturedImage) {
            return [summary, shareCard]
        }
        return [summary]
    }
}
