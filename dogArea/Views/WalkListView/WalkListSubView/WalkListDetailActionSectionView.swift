import SwiftUI

struct WalkListDetailActionSectionView: View {
    let onShare: () -> Void
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("다음 행동")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text("이 산책 기록은 다시 보기, 목표 확인, 공유에 활용할 수 있어요. 공유는 가장 적극적인 다음 행동이고 저장과 닫기는 보조 흐름입니다.")
                .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
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

            Button(action: onSave) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.to.line")
                    Text("사진으로 저장하기")
                }
            }
            .buttonStyle(AppFilledButtonStyle(role: .secondary))
            .accessibilityIdentifier("walklist.detail.action.save")
            .frame(minHeight: 50)

            Button(action: onDismiss) {
                Text("확인")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppFilledButtonStyle(role: .neutral))
            .accessibilityIdentifier("walklist.detail.action.dismiss")
            .frame(minHeight: 50)
        }
        .appCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walklist.detail.actions")
    }
}
