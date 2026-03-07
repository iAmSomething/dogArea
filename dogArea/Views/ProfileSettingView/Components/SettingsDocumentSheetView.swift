import SwiftUI

struct SettingsDocumentSheetView: View {
    let document: SettingsDocumentContent
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(document.title)
                            .font(.appScaledFont(for: .SemiBold, size: 28, relativeTo: .title2))
                            .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                        Text(document.subtitle)
                            .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                            .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    }

                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                            Text(section.body)
                                .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                                .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xCBD5E1))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .appCardSurface()
                    }

                    Text(document.footer)
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0x94A3B8))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color.appTabScaffoldBackground.ignoresSafeArea())
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        onClose()
                    }
                }
            }
        }
        .accessibilityIdentifier("sheet.settings.document.\(document.id)")
    }
}
