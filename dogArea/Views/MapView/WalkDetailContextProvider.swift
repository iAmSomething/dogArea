import UIKit

extension MapViewModel: WalkDetailContextProviding {
    var walkCreatedAt: TimeInterval {
        polygon.createdAt
    }

    var walkDuration: TimeInterval {
        polygon.walkingTime
    }

    var walkAreaM2: Double {
        polygon.walkingArea
    }

    var walkPointCount: Int {
        polygon.locations.count
    }

    var walkPetName: String {
        currentWalkingPetName
    }

    /// 면적 텍스트를 지정 단위 기준으로 반환합니다.
    /// - Parameters:
    ///   - areaSize: 변환할 면적 값(m²)입니다.
    ///   - isPyong: 평 단위 사용 여부입니다.
    /// - Returns: 단위가 반영된 포맷 문자열입니다.
    func calculatedAreaString(areaSize: Double, isPyong: Bool) -> String {
        calculatedAreaString(areaSize: Optional(areaSize), isPyong: isPyong)
    }

    /// 산책 상태 배너 메시지를 갱신합니다.
    /// - Parameter message: 사용자에게 노출할 메시지입니다.
    func setWalkStatusMessage(_ message: String) {
        walkStatusMessage = message
    }

    /// 지도 뷰모델의 산책 종료 액션을 실행합니다.
    /// - Parameter image: 종료 시 저장할 산책 결과 이미지입니다.
    func endWalk(with image: UIImage?) {
        endWalk(img: image)
    }
}
