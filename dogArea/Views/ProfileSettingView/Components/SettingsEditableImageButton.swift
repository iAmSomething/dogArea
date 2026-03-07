import SwiftUI

struct SettingsEditableImageButton<Content: View>: View {
    let title: String
    let accessibilityIdentifier: String
    let accessibilityLabel: String
    let action: () -> Void
    private let content: Content

    /// 설정 화면용 이미지 편집 진입 버튼을 구성합니다.
    /// - Parameters:
    ///   - title: 이미지 하단에 노출할 보조 안내 문구입니다.
    ///   - accessibilityIdentifier: UI 테스트와 접근성 탐색에 사용할 식별자입니다.
    ///   - accessibilityLabel: VoiceOver가 읽을 버튼 설명입니다.
    ///   - action: 버튼 탭 시 실행할 편집 진입 액션입니다.
    ///   - content: 이미지 미리보기 영역에 렌더링할 콘텐츠입니다.
    init(
        title: String,
        accessibilityIdentifier: String,
        accessibilityLabel: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    content

                    Label("사진 변경", systemImage: "photo.on.rectangle.angled")
                        .font(.appScaledFont(for: .SemiBold, size: 10, relativeTo: .caption2))
                        .foregroundStyle(Color.appInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.appSurface.opacity(0.96))
                        .overlay(
                            Capsule()
                                .stroke(Color.appTextLightGray.opacity(0.72), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                        .padding(10)
                }

                Text(title)
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("탭하면 편집 화면으로 이동합니다.")
    }
}
