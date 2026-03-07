import SwiftUI

struct MapFloatingControlColumnView: View {
    @Environment(\.appTabBarReservedHeight) private var reservedHeight

    let showsRecenterButton: Bool
    let showsAddPointButton: Bool
    let isAutoPointRecordMode: Bool
    let isAddPointLongPressModeEnabled: Bool
    let onRecenterTapped: () -> Void
    let onAddPointTapped: () -> Void
    let onAddPointLongPressEnded: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if showsRecenterButton {
                MapChromeIconButton(
                    systemImageName: "location.fill.viewfinder",
                    accessibilityIdentifier: "map.recenter",
                    accessibilityLabel: "내 위치로 다시 이동",
                    accessibilityHint: "지도를 현재 위치 기준으로 다시 맞춥니다.",
                    emphasized: false,
                    action: onRecenterTapped
                )
            }

            if showsAddPointButton {
                VStack(alignment: .trailing, spacing: 8) {
                    if isAutoPointRecordMode {
                        Text("자동 기록")
                            .font(.appFont(for: .SemiBold, size: 11))
                            .foregroundStyle(MapChromePalette.primaryText)
                            .mapChromePill(.success)
                    }
                    if isAddPointLongPressModeEnabled {
                        Text("길게 0.4s")
                            .font(.appFont(for: .SemiBold, size: 11))
                            .foregroundStyle(MapChromePalette.secondaryText)
                            .mapChromePill(.neutral)
                    }
                    addPointButton
                }
            }
        }
        .padding(.trailing, MapChromeLayoutMetrics.horizontalPadding)
        .padding(.bottom, showsAddPointButton ? reservedHeight + 92 : reservedHeight + 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private var addPointButton: some View {
        Button(action: onAddPointTapped) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(MapChromePalette.primaryText)
                .frame(
                    width: MapChromeLayoutMetrics.primaryFloatingButtonSize,
                    height: MapChromeLayoutMetrics.primaryFloatingButtonSize
                )
                .background(Color.appYellow)
                .overlay(
                    Circle()
                        .stroke(MapChromePalette.surfaceBorder, lineWidth: 1)
                )
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    guard isAddPointLongPressModeEnabled else { return }
                    onAddPointLongPressEnded()
                }
        )
        .accessibilityIdentifier("map.addPoint")
        .accessibilityLabel(isAddPointLongPressModeEnabled ? "길게 눌러 영역 추가" : "영역 추가")
        .accessibilityHint("추가 후 3초 안에 실행 취소할 수 있습니다")
    }
}
