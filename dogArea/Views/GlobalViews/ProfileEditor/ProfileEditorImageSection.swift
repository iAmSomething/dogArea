import SwiftUI
import UIKit
import Kingfisher

struct ProfileEditorImageSection: View {
    let title: String
    let subtitle: String?
    let remoteURL: String?
    @Binding var selectedImage: UIImage?
    let previewAccessibilityIdentifier: String
    let resetButtonTitle: String
    let resetButtonEnabled: Bool
    let allowsCamera: Bool
    let onReset: () -> Void
    let onCameraUnavailable: () -> Void

    @State private var pickerSourceType: UIImagePickerController.SourceType? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TitleTextView(
                title: title,
                type: .MediumTitle,
                subTitle: subtitle ?? ""
            )

            Button {
                pickerSourceType = .photoLibrary
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                            } else if let remoteURL,
                                      let url = URL(string: remoteURL) {
                                KFImage(url)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    Color.appTextLightGray.opacity(0.18)
                                    Image(systemName: "photo")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(Color.appOnSurfaceSecondary.opacity(0.7))
                                }
                            }
                        }
                        .frame(width: 94, height: 94)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.appSurfaceStroke.opacity(0.72), lineWidth: 1)
                        )

                        Label("사진 변경", systemImage: "photo.on.rectangle.angled")
                            .font(.appScaledFont(for: .SemiBold, size: 10, relativeTo: .caption2))
                            .foregroundStyle(Color.appOnSurfacePrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.appSurfaceRaised.opacity(0.96))
                            .overlay(
                                Capsule()
                                    .stroke(Color.appSurfaceStroke.opacity(0.72), lineWidth: 1)
                            )
                            .clipShape(Capsule())
                            .padding(8)
                    }

                    Text("사진을 탭하면 앨범이 바로 열립니다.")
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(previewAccessibilityIdentifier)
            .accessibilityLabel("\(title) 사진 변경")
            .accessibilityHint("탭하면 사진 보관함을 엽니다.")

            HStack(spacing: 8) {
                if allowsCamera {
                    Button("카메라") {
                        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                            onCameraUnavailable()
                            return
                        }
                        pickerSourceType = .camera
                    }
                    .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
                    .frame(minHeight: 44)
                }

                Button(resetButtonTitle) {
                    onReset()
                }
                .disabled(resetButtonEnabled == false)
                .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
                .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 16)
        .appCardSurface()
        .sheet(
            isPresented: Binding(
                get: { pickerSourceType != nil },
                set: { isPresented in
                    if isPresented == false {
                        pickerSourceType = nil
                    }
                }
            )
        ) {
            if let pickerSourceType {
                ImagePicker(image: $selectedImage, type: pickerSourceType)
                    .ignoresSafeArea()
            }
        }
    }
}
