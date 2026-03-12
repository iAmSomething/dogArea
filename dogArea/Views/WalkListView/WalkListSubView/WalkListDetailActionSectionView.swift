import SwiftUI

struct WalkListDetailActionSectionView: View {
    let onShare: () -> Void
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("다음 행동")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text("공유를 우선 두고, 저장과 닫기는 바로 이어서 선택할 수 있게 정리했어요.")
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onShare) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("공유하기")
                }
            }
            .buttonStyle(AppFilledButtonStyle(role: .primary))
            .accessibilityIdentifier("walklist.detail.action.share")
            .frame(minHeight: 50)

            HStack(spacing: 10) {
                Button(action: onSave) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.to.line")
                        Text("저장")
                    }
                }
                .buttonStyle(AppFilledButtonStyle(role: .secondary))
                .accessibilityIdentifier("walklist.detail.action.save")
                .frame(minHeight: 50)
                .frame(maxWidth: .infinity)

                Button(action: onDismiss) {
                    Text("확인")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppFilledButtonStyle(role: .neutral))
                .accessibilityIdentifier("walklist.detail.action.dismiss")
                .frame(minHeight: 50)
                .frame(maxWidth: .infinity)
            }
        }
        .appCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walklist.detail.actions")
    }
}
