import SwiftUI

extension MapViewModel {
    /// 시즌 타일 채움 색을 계산합니다.
    /// - Parameter score: 시즌 셀에 누적된 정규화 점수입니다.
    /// - Returns: 시즌 타일 단계에 대응하는 채움 색입니다.
    func heatmapColor(for score: Double) -> Color {
        let level = seasonTileIntensityLevel(for: score)
        let status = seasonTileStatusText(for: score)
        switch (level, status) {
        case (0, _):
            return Color.appGreen
        case (1, _):
            return Color.appYellowPale
        case (2, "점령"):
            return Color.appPeach
        case (2, _):
            return Color.appYellow
        case (3, "점령"):
            return Color.appRed
        default:
            return Color.appPeach
        }
    }

    /// 시즌 타일 기본 채움 투명도를 계산합니다.
    /// - Parameter score: 시즌 셀에 누적된 정규화 점수입니다.
    /// - Returns: 날씨 tint 보정 전 기본 채움 투명도입니다.
    func heatmapOpacity(for score: Double) -> Double {
        switch seasonTileIntensityLevel(for: score) {
        case 0:
            return 0.10
        case 1:
            return 0.14
        case 2:
            return 0.18
        default:
            return 0.22
        }
    }

    /// 시즌 타일 셀의 채움 색을 계산합니다.
    /// - Parameter tile: 지도에 렌더링할 시즌 타일 셀 표현입니다.
    /// - Returns: 셀의 상태/강도에 대응하는 채움 색입니다.
    func seasonTileFillColor(for tile: MapSeasonTilePresentation) -> Color {
        heatmapColor(for: tile.score)
    }

    /// 시즌 타일 셀의 채움 투명도를 계산합니다.
    /// - Parameter tile: 지도에 렌더링할 시즌 타일 셀 표현입니다.
    /// - Returns: 날씨 tint와 선택 정책이 반영된 채움 투명도입니다.
    func seasonTileFillOpacity(for tile: MapSeasonTilePresentation) -> Double {
        let weatherCompensation = max(0.58, 1.0 - (weatherOverlayOpacity * 0.85))
        let baseOpacity = heatmapOpacity(for: tile.score) * weatherCompensation
        return min(0.24, max(0.06, baseOpacity))
    }

    /// 시즌 타일 셀의 테두리 색을 계산합니다.
    /// - Parameter tile: 지도에 렌더링할 시즌 타일 셀 표현입니다.
    /// - Returns: 점령/유지 상태를 식별하는 테두리 색입니다.
    func seasonTileStrokeColor(for tile: MapSeasonTilePresentation) -> Color {
        switch tile.status {
        case .occupied:
            return Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74)
        case .maintained:
            return Color.appDynamicHex(light: 0x0F766E, dark: 0x5EEAD4)
        }
    }

    /// 시즌 타일 셀의 테두리 스타일을 계산합니다.
    /// - Parameter tile: 지도에 렌더링할 시즌 타일 셀 표현입니다.
    /// - Returns: 점령/유지 상태에 대응하는 스트로크 스타일입니다.
    func seasonTileStrokeStyle(for tile: MapSeasonTilePresentation) -> StrokeStyle {
        switch tile.status {
        case .occupied:
            return StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
        case .maintained:
            return StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round, dash: [7, 5])
        }
    }

    /// 선택한 시즌 타일에 적용할 halo 색을 계산합니다.
    /// - Parameter tile: 선택 강조를 적용할 시즌 타일입니다.
    /// - Returns: 선택 halo에 사용할 강조 색입니다.
    func seasonTileSelectionHaloColor(for tile: MapSeasonTilePresentation) -> Color {
        switch tile.status {
        case .occupied:
            return Color.appYellow.opacity(0.92)
        case .maintained:
            return Color.appDynamicHex(light: 0x94A3B8, dark: 0xCBD5E1).opacity(0.92)
        }
    }

    /// 선택한 시즌 타일에 적용할 halo 스트로크 스타일을 계산합니다.
    /// - Parameter tile: 선택 강조를 적용할 시즌 타일입니다.
    /// - Returns: 선택 halo 스트로크 스타일입니다.
    func seasonTileSelectionHaloStyle(for tile: MapSeasonTilePresentation) -> StrokeStyle {
        let dash: [CGFloat] = tile.status == .maintained ? [10, 6] : [12, 0]
        return StrokeStyle(lineWidth: 5.6, lineCap: .round, lineJoin: .round, dash: dash)
    }
}
