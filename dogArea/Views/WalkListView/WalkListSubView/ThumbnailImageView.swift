import SwiftUI

struct ThumbnailImageView: View {
    let image: UIImage?
    var size: CGFloat = 60
    var cornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x1F2937))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "map.fill")
                        .font(.system(size: max(18, size * 0.24), weight: .semibold))
                        .foregroundStyle(Color.appInk.opacity(0.7))
                    Text("기록 요약")
                        .font(.appScaledFont(for: .SemiBold, size: 10, relativeTo: .caption2))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
    }
}
