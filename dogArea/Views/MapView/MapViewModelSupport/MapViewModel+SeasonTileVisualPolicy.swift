import SwiftUI

/// 시즌 타일과 산책 오버레이가 함께 보일 때의 지도 렌더 상황입니다.
enum MapSeasonTileRenderScenario: String {
    case seasonOnly
    case seasonWithStoredPolygonSurface
    case seasonWithActiveWalkRoute
}

extension MapViewModel {
    /// 현재 지도 상태를 시즌 타일 렌더 시나리오로 분류합니다.
    /// - Parameters:
    ///   - hasStoredPolygonSurface: 저장된 산책 polygon surface가 함께 보이면 `true`입니다.
    ///   - hasActiveWalkRoute: 현재 산책 route가 함께 보이면 `true`입니다.
    /// - Returns: 시즌 타일이 어떤 보조 레이어와 경쟁하는지 나타내는 렌더 시나리오입니다.
    func seasonTileRenderScenario(
        hasStoredPolygonSurface: Bool,
        hasActiveWalkRoute: Bool
    ) -> MapSeasonTileRenderScenario {
        if hasActiveWalkRoute {
            return .seasonWithActiveWalkRoute
        }
        if hasStoredPolygonSurface {
            return .seasonWithStoredPolygonSurface
        }
        return .seasonOnly
    }

    /// 시즌 타일 채움 색을 계산합니다.
    /// - Parameter score: 시즌 셀에 누적된 정규화 점수입니다.
    /// - Returns: stroke보다 한 단계 물러난 보조 채움 색입니다.
    func heatmapColor(for score: Double) -> Color {
        let level = seasonTileIntensityLevel(for: score)
        let status = seasonTileStatusText(for: score)

        switch (status, level) {
        case ("유지", 0):
            return Color.appDynamicHex(light: 0xDCFCE7, dark: 0x134E4A)
        case ("유지", _):
            return Color.appDynamicHex(light: 0xD1FAE5, dark: 0x164E63)
        case ("점령", 2):
            return Color.appDynamicHex(light: 0xFDE7D3, dark: 0x7C2D12)
        case ("점령", _):
            return Color.appDynamicHex(light: 0xF8D9C2, dark: 0x9A3412)
        default:
            return Color.appDynamicHex(light: 0xF5E7D8, dark: 0x78350F)
        }
    }

    /// 시즌 타일 기본 채움 투명도를 계산합니다.
    /// - Parameters:
    ///   - score: 시즌 셀에 누적된 정규화 점수입니다.
    ///   - renderScenario: 현재 지도에서 시즌 타일이 경쟁하는 레이어 상황입니다.
    /// - Returns: 날씨 tint와 동시 노출 레이어를 반영한 채움 투명도입니다.
    func heatmapOpacity(
        for score: Double,
        renderScenario: MapSeasonTileRenderScenario
    ) -> Double {
        let baseOpacity: Double
        switch seasonTileIntensityLevel(for: score) {
        case 0:
            baseOpacity = 0.10
        case 1:
            baseOpacity = 0.13
        case 2:
            baseOpacity = 0.16
        default:
            baseOpacity = 0.19
        }

        let scenarioCompensation: Double
        switch renderScenario {
        case .seasonOnly:
            scenarioCompensation = 1.0
        case .seasonWithStoredPolygonSurface:
            scenarioCompensation = 0.68
        case .seasonWithActiveWalkRoute:
            scenarioCompensation = 0.52
        }

        let weatherCompensation = max(0.50, 1.0 - (weatherOverlayOpacity * 1.15))
        let adjustedOpacity = baseOpacity * scenarioCompensation * weatherCompensation
        return min(0.16, max(0.035, adjustedOpacity))
    }

    /// 시즌 타일 셀의 채움 색을 계산합니다.
    /// - Parameter tile: 지도에 렌더링할 시즌 타일 셀 표현입니다.
    /// - Returns: 셀의 상태/강도에 대응하는 보조 채움 색입니다.
    func seasonTileFillColor(for tile: MapSeasonTilePresentation) -> Color {
        heatmapColor(for: tile.score)
    }

    /// 시즌 타일 셀의 채움 투명도를 계산합니다.
    /// - Parameters:
    ///   - tile: 지도에 렌더링할 시즌 타일 셀 표현입니다.
    ///   - renderScenario: 현재 지도에서 시즌 타일이 경쟁하는 레이어 상황입니다.
    /// - Returns: 채움이 주 레이어를 가리지 않도록 보정된 투명도입니다.
    func seasonTileFillOpacity(
        for tile: MapSeasonTilePresentation,
        renderScenario: MapSeasonTileRenderScenario
    ) -> Double {
        heatmapOpacity(for: tile.score, renderScenario: renderScenario)
    }

    /// 시즌 타일 셀의 테두리 색을 계산합니다.
    /// - Parameters:
    ///   - tile: 지도에 렌더링할 시즌 타일 셀 표현입니다.
    ///   - renderScenario: 현재 지도에서 시즌 타일이 경쟁하는 레이어 상황입니다.
    /// - Returns: 점령/유지 상태를 식별하는 주된 테두리 색입니다.
    func seasonTileStrokeColor(
        for tile: MapSeasonTilePresentation,
        renderScenario: MapSeasonTileRenderScenario
    ) -> Color {
        let baseColor: Color
        switch tile.status {
        case .occupied:
            baseColor = Color.appDynamicHex(light: 0xB45309, dark: 0xFED7AA)
        case .maintained:
            baseColor = Color.appDynamicHex(light: 0x0F766E, dark: 0x99F6E4)
        }

        switch renderScenario {
        case .seasonOnly, .seasonWithStoredPolygonSurface:
            return baseColor.opacity(0.96)
        case .seasonWithActiveWalkRoute:
            return baseColor.opacity(0.90)
        }
    }

    /// 시즌 타일 셀의 테두리 스타일을 계산합니다.
    /// - Parameters:
    ///   - tile: 지도에 렌더링할 시즌 타일 셀 표현입니다.
    ///   - renderScenario: 현재 지도에서 시즌 타일이 경쟁하는 레이어 상황입니다.
    /// - Returns: 점령/유지 상태에 대응하는 stroke-first 스타일입니다.
    func seasonTileStrokeStyle(
        for tile: MapSeasonTilePresentation,
        renderScenario: MapSeasonTileRenderScenario
    ) -> StrokeStyle {
        let lineWidth: CGFloat
        switch (tile.status, renderScenario) {
        case (.occupied, .seasonWithActiveWalkRoute):
            lineWidth = 2.2
        case (.occupied, _):
            lineWidth = 2.8
        case (.maintained, .seasonWithActiveWalkRoute):
            lineWidth = 1.5
        case (.maintained, _):
            lineWidth = 1.8
        }

        switch tile.status {
        case .occupied:
            return StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        case .maintained:
            return StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round, dash: [7, 5])
        }
    }

    /// 선택한 시즌 타일에 적용할 halo 색을 계산합니다.
    /// - Parameter tile: 선택 강조를 적용할 시즌 타일입니다.
    /// - Returns: fill을 더 짙게 만들지 않고 outline만 올리는 강조 색입니다.
    func seasonTileSelectionHaloColor(for tile: MapSeasonTilePresentation) -> Color {
        switch tile.status {
        case .occupied:
            return Color.appYellow.opacity(0.94)
        case .maintained:
            return Color.appDynamicHex(light: 0xCBD5E1, dark: 0xE2E8F0).opacity(0.92)
        }
    }

    /// 선택한 시즌 타일에 적용할 halo 스트로크 스타일을 계산합니다.
    /// - Parameter tile: 선택 강조를 적용할 시즌 타일입니다.
    /// - Returns: stroke-first 상태를 유지하는 선택 halo 스트로크 스타일입니다.
    func seasonTileSelectionHaloStyle(for tile: MapSeasonTilePresentation) -> StrokeStyle {
        let dash: [CGFloat] = tile.status == .maintained ? [9, 6] : []
        return StrokeStyle(lineWidth: 6.0, lineCap: .round, lineJoin: .round, dash: dash)
    }

    /// 시즌 타일과 함께 보일 저장된 산책 polygon 채움 투명도를 계산합니다.
    /// - Parameter renderScenario: 현재 지도에서 시즌 타일이 경쟁하는 레이어 상황입니다.
    /// - Returns: 저장 polygon이 주 레이어처럼 보이지 않도록 보정된 투명도입니다.
    func storedWalkPolygonFillOpacity(for renderScenario: MapSeasonTileRenderScenario) -> Double {
        switch renderScenario {
        case .seasonOnly:
            return 0.18
        case .seasonWithStoredPolygonSurface:
            return 0.12
        case .seasonWithActiveWalkRoute:
            return 0.09
        }
    }

    /// 시즌 타일과 함께 보일 저장된 산책 polygon 테두리 두께를 계산합니다.
    /// - Parameter renderScenario: 현재 지도에서 시즌 타일이 경쟁하는 레이어 상황입니다.
    /// - Returns: 저장 polygon stroke의 두께입니다.
    func storedWalkPolygonStrokeLineWidth(for renderScenario: MapSeasonTileRenderScenario) -> CGFloat {
        switch renderScenario {
        case .seasonOnly:
            return 0.7
        case .seasonWithStoredPolygonSurface:
            return 0.55
        case .seasonWithActiveWalkRoute:
            return 0.5
        }
    }

    /// 저장된 산책 polygon의 surface fill 색을 계산합니다.
    /// - Parameters:
    ///   - isSeasonTileMapVisible: 시즌 점령 지도가 현재 켜져 있으면 `true`입니다.
    ///   - renderScenario: 현재 지도에서 시즌 타일이 경쟁하는 레이어 상황입니다.
    /// - Returns: 시즌 지도가 켜진 경우 `nil`을 반환해 fill을 제거하고, 그렇지 않으면 저장 polygon fill 색을 반환합니다.
    func storedWalkPolygonFillColor(
        isSeasonTileMapVisible: Bool,
        renderScenario: MapSeasonTileRenderScenario
    ) -> Color? {
        guard isSeasonTileMapVisible == false else { return nil }
        return Color.appYellow.opacity(storedWalkPolygonFillOpacity(for: renderScenario))
    }

    /// 저장된 산책 polygon outline 색을 계산합니다.
    /// - Parameters:
    ///   - isSeasonTileMapVisible: 시즌 점령 지도가 현재 켜져 있으면 `true`입니다.
    ///   - renderScenario: 현재 지도에서 시즌 타일이 경쟁하는 레이어 상황입니다.
    /// - Returns: 시즌 점령 지도가 켜진 경우 한 단계 낮춘 outline 색을, 그렇지 않으면 기본 outline 색을 반환합니다.
    func storedWalkPolygonStrokeColor(
        isSeasonTileMapVisible: Bool,
        renderScenario: MapSeasonTileRenderScenario
    ) -> Color {
        let opacity: Double
        if isSeasonTileMapVisible {
            switch renderScenario {
            case .seasonOnly:
                opacity = 0.82
            case .seasonWithStoredPolygonSurface:
                opacity = 0.70
            case .seasonWithActiveWalkRoute:
                opacity = 0.62
            }
        } else {
            switch renderScenario {
            case .seasonOnly:
                opacity = 0.96
            case .seasonWithStoredPolygonSurface:
                opacity = 0.90
            case .seasonWithActiveWalkRoute:
                opacity = 0.84
            }
        }

        return Color.appYellow.opacity(opacity)
    }

    /// 현재 산책 route 색을 계산합니다.
    /// - Parameter renderScenario: 현재 지도에서 시즌 타일이 경쟁하는 레이어 상황입니다.
    /// - Returns: 시즌 타일 위에서도 주 레이어로 읽히는 route stroke 색입니다.
    func activeWalkRouteStrokeColor(for renderScenario: MapSeasonTileRenderScenario) -> Color {
        switch renderScenario {
        case .seasonWithActiveWalkRoute:
            return Color.appGreen.opacity(0.96)
        case .seasonOnly, .seasonWithStoredPolygonSurface:
            return Color.appGreen.opacity(0.90)
        }
    }
}
