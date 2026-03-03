//
//  MapAreaCalculationService.swift
//  dogArea
//
//  Created by Codex on 3/3/26.
//

import Foundation

protocol MapAreaCalculationServicing {
    /// 산책 좌표 목록으로 다각형 면적(m²)을 계산합니다.
    /// - Parameter points: 다각형 경계를 이루는 위치 목록입니다.
    /// - Returns: 좌표 평면 근사식으로 계산한 절대 면적 값(m²)입니다.
    func calculateArea(points: [Location]) -> Double

    /// 면적 값을 UI 표시용 문자열로 포맷합니다.
    /// - Parameters:
    ///   - area: 표시할 원본 면적 값(m²)입니다.
    ///   - isPyong: `true`면 평 단위, `false`면 제곱미터 단위를 사용합니다.
    /// - Returns: 단위 규칙(㎡/만㎡/k㎡/평/만평)이 반영된 문자열입니다.
    func formattedAreaString(area: Double, isPyong: Bool) -> String
}

final class MapAreaCalculationService: MapAreaCalculationServicing {
    /// 산책 좌표 목록으로 다각형 면적(m²)을 계산합니다.
    /// - Parameter points: 다각형 경계를 이루는 위치 목록입니다.
    /// - Returns: 좌표 평면 근사식으로 계산한 절대 면적 값(m²)입니다.
    func calculateArea(points: [Location]) -> Double {
        guard points.count >= 3 else { return 0 }
        let earthRadius = 6_371_000.0
        var area: Double = 0

        for index in 0..<points.count {
            let currentPoint = points[index]
            let nextPoint = points[(index + 1) % points.count]

            let latitude1 = currentPoint.coordinate.latitude * .pi / 180
            let longitude1 = currentPoint.coordinate.longitude * .pi / 180
            let latitude2 = nextPoint.coordinate.latitude * .pi / 180
            let longitude2 = nextPoint.coordinate.longitude * .pi / 180

            let x1 = earthRadius * cos(latitude1) * cos(longitude1)
            let y1 = earthRadius * cos(latitude1) * sin(longitude1)
            let x2 = earthRadius * cos(latitude2) * cos(longitude2)
            let y2 = earthRadius * cos(latitude2) * sin(longitude2)

            area += (x1 * y2 - x2 * y1) / 2
        }
        return abs(area)
    }

    /// 면적 값을 UI 표시용 문자열로 포맷합니다.
    /// - Parameters:
    ///   - area: 표시할 원본 면적 값(m²)입니다.
    ///   - isPyong: `true`면 평 단위, `false`면 제곱미터 단위를 사용합니다.
    /// - Returns: 단위 규칙(㎡/만㎡/k㎡/평/만평)이 반영된 문자열입니다.
    func formattedAreaString(area: Double, isPyong: Bool) -> String {
        if isPyong {
            if area / 3.3 > 10_000 {
                return String(format: "%.1f", area / 33_333) + "만 평"
            }
            return String(format: "%.1f", area / 3.3) + "평"
        }

        if area > 100_000.0 {
            return String(format: "%.2f", area / 1_000_000) + "k㎡"
        }
        if area > 10_000.0 {
            return String(format: "%.2f", area / 10_000) + "만 ㎡"
        }
        return String(format: "%.2f", area) + "㎡"
    }
}
