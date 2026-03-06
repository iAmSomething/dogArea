import SwiftUI

struct ProfileFieldEditSheet: View {
    @StateObject private var sheetViewModel: ProfileFieldEditSheetViewModel
    let onSaved: (String) -> Void
    let onClose: () -> Void

    /// 프로필 편집 시트의 초기 상태를 구성합니다.
    /// - Parameters:
    ///   - viewModel: 사용자/반려견 정보와 저장 액션을 제공하는 설정 뷰모델입니다.
    ///   - onSaved: 저장 성공 시 사용자에게 보여줄 메시지를 전달하는 콜백입니다.
    ///   - onClose: 시트 종료가 필요할 때 부모 화면의 표시 상태를 갱신하는 콜백입니다.
    init(viewModel: SettingViewModel, onSaved: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.onSaved = onSaved
        self.onClose = onClose
        _sheetViewModel = StateObject(wrappedValue: ProfileFieldEditSheetViewModel(provider: viewModel))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ProfileEditorUserFieldsCard(
                        userName: $sheetViewModel.userName,
                        profileMessage: $sheetViewModel.profileMessage
                    )

                    ProfileEditorImageSection(
                        title: "사용자 프로필 이미지",
                        subtitle: "새 사진을 선택하면 저장 시 프로필에 반영됩니다.",
                        remoteURL: sheetViewModel.userProfileImageURL,
                        selectedImage: $sheetViewModel.userProfileImage,
                        resetButtonTitle: "선택 취소",
                        resetButtonEnabled: sheetViewModel.userProfileImage != nil,
                        allowsCamera: true,
                        onReset: {
                            sheetViewModel.userProfileImage = nil
                        },
                        onCameraUnavailable: {
                            sheetViewModel.errorMessage = "현재 기기에서는 카메라를 사용할 수 없습니다."
                        }
                    )

                    ProfileEditorPetFieldsCard(
                        title: "\(sheetViewModel.selectedPetName) 정보",
                        subtitle: "선택된 반려견 기준으로 이름/견종/나이/성별을 수정합니다.",
                        petName: $sheetViewModel.petName,
                        breed: $sheetViewModel.breed,
                        ageYearsText: $sheetViewModel.ageYearsText,
                        gender: $sheetViewModel.gender,
                        requiresPetName: true
                    )

                    ProfileEditorImageSection(
                        title: "반려견 프로필 이미지",
                        subtitle: "새 사진을 선택하면 저장 시 선택 반려견에 반영됩니다.",
                        remoteURL: sheetViewModel.petProfileImageURL,
                        selectedImage: $sheetViewModel.petProfileImage,
                        resetButtonTitle: "선택 취소",
                        resetButtonEnabled: sheetViewModel.petProfileImage != nil,
                        allowsCamera: true,
                        onReset: {
                            sheetViewModel.petProfileImage = nil
                        },
                        onCameraUnavailable: {
                            sheetViewModel.errorMessage = "현재 기기에서는 카메라를 사용할 수 없습니다."
                        }
                    )

                    caricatureCard

                    if let errorMessage = sheetViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 16)
                            .accessibilityIdentifier("sheet.settings.profileEdit.error")
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color.appTabScaffoldBackground.ignoresSafeArea())
            .navigationTitle("프로필 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        onClose()
                    }
                    .accessibilityIdentifier("sheet.settings.profileEdit.cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(sheetViewModel.isSaving ? "저장 중..." : "저장") {
                        Task {
                            if await sheetViewModel.saveChanges() {
                                await MainActor.run {
                                    #if DEBUG
                                    print("[ProfileEditSheet] dismiss requested after save success")
                                    #endif
                                    onSaved("프로필 정보를 저장했어요.")
                                    onClose()
                                }
                            } else {
                                #if DEBUG
                                print("[ProfileEditSheet] dismiss skipped because save failed")
                                #endif
                            }
                        }
                    }
                    .disabled(sheetViewModel.isSaving || sheetViewModel.isGeneratingCaricature)
                    .accessibilityIdentifier("sheet.settings.profileEdit.save")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sheet.settings.profileEdit")
    }

    private var caricatureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("반려견 캐리커처")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
            Text("현재 상태: \(sheetViewModel.caricatureStatusText)")
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                .foregroundStyle(Color.appTextDarkGray)
            Button(sheetViewModel.isGeneratingCaricature ? "생성 중..." : "캐리커처 생성/재생성") {
                Task {
                    await sheetViewModel.requestCaricatureRegeneration()
                }
            }
            .disabled(sheetViewModel.isGeneratingCaricature)
            .buttonStyle(AppFilledButtonStyle(role: .secondary))
            .frame(minHeight: 44)

            if let caricatureMessage = sheetViewModel.caricatureMessage {
                Text(caricatureMessage)
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                    .foregroundStyle(Color.appTextDarkGray)
            }
        }
        .padding(.horizontal, 16)
        .appCardSurface()
    }
}
