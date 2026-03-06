import SwiftUI
import UIKit
import Kingfisher

struct ProfileEditorImageSection: View {
    let title: String
    let subtitle: String?
    let remoteURL: String?
    @Binding var selectedImage: UIImage?
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
                            .foregroundStyle(Color.appTextDarkGray.opacity(0.6))
                    }
                }
            }
            .frame(width: 94, height: 94)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.appTextLightGray.opacity(0.6), lineWidth: 1)
            )
            .accessibilityLabel("\(title) 미리보기")

            HStack(spacing: 8) {
                Button("앨범") {
                    pickerSourceType = .photoLibrary
                }
                .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                .frame(minHeight: 44)

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
