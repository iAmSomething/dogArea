import SwiftUI

struct WalkListDetailMapSectionView: View {
    let polygon: Polygon
    @Binding var selectedLocation: UUID?
    let selectedPointSummary: String
    let hasMapContent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("영역 지도")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text("포인트 칩을 누르면 해당 시점을 지도에서 바로 강조합니다.")
                .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .fixedSize(horizontal: false, vertical: true)
            Text(selectedPointSummary)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFDE68A))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appDynamicHex(light: 0xFEF3C7, dark: 0x78350F, alpha: 0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if hasMapContent {
                SimpleMapView(polygon: polygon, selectedLocation: $selectedLocation)
                    .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
                    )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("지도를 만들 수 없는 기록이에요")
                        .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                        .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xE2E8F0))
                    Text("포인트가 너무 적거나 좌표 정보가 부족하면 지도 미리보기를 생략합니다.")
                        .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
                .padding(16)
                .background(Color.appDynamicHex(light: 0xF8FAFC, dark: 0x0F172A, alpha: 0.72))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .appCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walklist.detail.map")
    }
}
