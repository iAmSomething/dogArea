import SwiftUI

struct WalkListDetailMetaSectionView: View {
    let rows: [WalkListDetailMetaRowModel]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("세션 메타")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            VStack(spacing: 10) {
                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: 12) {
                        Text(row.title)
                            .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .subheadline))
                            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        Spacer(minLength: 12)
                        Text(row.value)
                            .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .body))
                            .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 6)
                    if row.id != rows.last?.id {
                        Divider()
                    }
                }
            }
        }
        .appCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walklist.detail.meta")
    }
}
