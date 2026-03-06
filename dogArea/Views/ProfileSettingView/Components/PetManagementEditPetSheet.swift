import SwiftUI

struct PetManagementEditPetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PetManagementEditPetSheetViewModel
    let onSaved: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ProfileEditorImageSection(
                        title: "반려견 프로필 이미지",
                        subtitle: "새 사진을 선택하거나 기존 이미지를 제거할 수 있습니다.",
                        remoteURL: viewModel.remoteImageURL,
                        selectedImage: $viewModel.petProfileImage,
                        resetButtonTitle: "이미지 제거",
                        resetButtonEnabled: viewModel.petProfileImage != nil || viewModel.remoteImageURL != nil,
                        allowsCamera: true,
                        onReset: {
                            viewModel.requestRemoveProfileImage()
                        },
                        onCameraUnavailable: {
                            viewModel.errorMessage = "현재 기기에서는 카메라를 사용할 수 없습니다."
                        }
                    )

                    ProfileEditorPetFieldsCard(
                        title: "\(viewModel.title) 정보",
                        subtitle: "반려견 이름은 필수, 나머지 정보는 선택입니다.",
                        petName: $viewModel.petName,
                        breed: $viewModel.breed,
                        ageYearsText: $viewModel.ageYearsText,
                        gender: $viewModel.gender,
                        requiresPetName: true
                    )

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 16)
                            .accessibilityIdentifier("sheet.settings.petManagement.edit.error")
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color.appTabScaffoldBackground.ignoresSafeArea())
            .navigationTitle("반려견 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                    .accessibilityIdentifier("sheet.settings.petManagement.edit.cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isSaving ? "저장 중..." : "저장") {
                        Task {
                            if await viewModel.saveChanges() {
                                await MainActor.run {
                                    onSaved()
                                    dismiss()
                                }
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                    .accessibilityIdentifier("sheet.settings.petManagement.edit.save")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sheet.settings.petManagement.edit")
    }
}
