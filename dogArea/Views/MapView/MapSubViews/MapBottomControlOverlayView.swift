import SwiftUI

enum MapBottomControlOverlayMetrics {
    static let floatingControlsBottomSpacingWhenPrimaryVisible: CGFloat = 44
    static let floatingControlsBottomSpacingWhenPrimaryHidden: CGFloat = 28
    static let selectedTrayBottomSpacingWhenPrimaryVisible: CGFloat = 156
    static let selectedTrayBottomSpacingWhenPrimaryHidden: CGFloat = 20

    /// 하단 주행동 surface의 기본 바닥 여백을 계산합니다.
    /// - Parameter reservedHeight: 전역 탭 스캐폴드가 예약한 하단 높이입니다.
    /// - Returns: 탭바와 겹치지 않는 주행동 surface의 하단 여백입니다.
    static func primaryActionBottomPadding(reservedHeight: CGFloat) -> CGFloat {
        max(
            reservedHeight - AppTabLayoutMetrics.floatingOverlayLift,
            AppTabLayoutMetrics.minimumBottomPadding
        )
    }

    /// 우측 플로팅 조작 버튼군의 바닥 여백을 계산합니다.
    /// - Parameters:
    ///   - reservedHeight: 전역 탭 스캐폴드가 예약한 하단 높이입니다.
    ///   - showsPrimaryAction: 중앙 주행동 surface가 노출 중인지 여부입니다.
    /// - Returns: 우측 플로팅 버튼군에 적용할 최종 하단 여백입니다.
    static func floatingControlsBottomPadding(
        reservedHeight: CGFloat,
        showsPrimaryAction: Bool
    ) -> CGFloat {
        let basePadding = primaryActionBottomPadding(reservedHeight: reservedHeight)
        let additionalSpacing = showsPrimaryAction
            ? floatingControlsBottomSpacingWhenPrimaryVisible
            : floatingControlsBottomSpacingWhenPrimaryHidden
        return basePadding + additionalSpacing
    }

    /// 선택한 산책 기록 트레이의 바닥 여백을 계산합니다.
    /// - Parameters:
    ///   - reservedHeight: 전역 탭 스캐폴드가 예약한 하단 높이입니다.
    ///   - showsPrimaryAction: 중앙 주행동 surface가 노출 중인지 여부입니다.
    /// - Returns: 선택한 산책 기록 트레이에 적용할 최종 하단 여백입니다.
    static func selectedTrayBottomPadding(
        reservedHeight: CGFloat,
        showsPrimaryAction: Bool
    ) -> CGFloat {
        let basePadding = primaryActionBottomPadding(reservedHeight: reservedHeight)
        let additionalSpacing = showsPrimaryAction
            ? selectedTrayBottomSpacingWhenPrimaryVisible
            : selectedTrayBottomSpacingWhenPrimaryHidden
        return basePadding + additionalSpacing
    }
}

struct MapBottomControlOverlayView: View {
    @Environment(\.appTabBarReservedHeight) private var reservedHeight

    let showsPrimaryAction: Bool
    let primaryAction: AnyView
    let floatingControls: AnyView?
    let selectedPolygonTray: AnyView?

    var body: some View {
        ZStack(alignment: .bottom) {
            if let selectedPolygonTray {
                selectedPolygonTray
                    .padding(
                        .bottom,
                        MapBottomControlOverlayMetrics.selectedTrayBottomPadding(
                            reservedHeight: reservedHeight,
                            showsPrimaryAction: showsPrimaryAction
                        )
                    )
                    .zIndex(1)
            }

            if showsPrimaryAction {
                primaryAction
                    .padding(
                        .bottom,
                        MapBottomControlOverlayMetrics.primaryActionBottomPadding(
                            reservedHeight: reservedHeight
                        )
                    )
                    .zIndex(2)
            }

            if let floatingControls {
                floatingControls
                    .padding(.trailing, MapChromeLayoutMetrics.horizontalPadding)
                    .padding(
                        .bottom,
                        MapBottomControlOverlayMetrics.floatingControlsBottomPadding(
                            reservedHeight: reservedHeight,
                            showsPrimaryAction: showsPrimaryAction
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .zIndex(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.bottomControls")
    }
}
