import SwiftUI

struct PetManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var viewModel: SettingViewModel
    @StateObject private var sheetViewModel: PetManagementSheetViewModel
    @State private var editSheetViewModel: PetManagementEditPetSheetViewModel? = nil

    /// 반려견 관리 시트를 구성하고 설정 뷰모델을 반려견 관리 전용 뷰모델에 연결합니다.
    /// - Parameter viewModel: 설정 화면의 원본 상태와 저장 액션을 제공하는 뷰모델입니다.
    init(viewModel: SettingViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._sheetViewModel = StateObject(wrappedValue: PetManagementSheetViewModel(provider: viewModel))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    headerSection

                    activePetsSection

                    if sheetViewModel.inactivePets.isEmpty == false {
                        inactivePetsSection
                    }

                    addPetSection

                    if let errorMessage = sheetViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 16)
                            .accessibilityIdentifier("sheet.settings.petManagement.error")
                    }

                    if let successMessage = sheetViewModel.successMessage {
                        Text(successMessage)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                            .foregroundStyle(Color.appGreen)
                            .padding(.horizontal, 16)
                            .accessibilityIdentifier("sheet.settings.petManagement.success")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color.appTabScaffoldBackground.ignoresSafeArea())
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sheet.settings.petManagement")
        .onAppear {
            sheetViewModel.reload()
        }
        .onReceive(viewModel.$userInfo) { _ in
            sheetViewModel.reload()
        }
        .sheet(item: $editSheetViewModel) { editViewModel in
            PetManagementEditPetSheet(viewModel: editViewModel) {
                sheetViewModel.reload()
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("반려견 관리")
                    .font(.appScaledFont(for: .SemiBold, size: 24, relativeTo: .title2))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Text("대표 반려견, 활성 상태, 프로필 정보를 여기서 정리합니다.")
                    .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            }

            Spacer(minLength: 0)

            Button("닫기") {
                dismiss()
            }
            .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
            .frame(minHeight: 44)
            .accessibilityIdentifier("sheet.settings.petManagement.close")
        }
        .appCardSurface()
    }

    private var activePetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("활성 반려견")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            if sheetViewModel.activePets.isEmpty {
                Text("활성 반려견이 아직 없습니다.")
                    .font(.appScaledFont(for: .Regular, size: 13, relativeTo: .body))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            }

            ForEach(sheetViewModel.activePets, id: \.petId) { pet in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(pet.petName)
                            .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                            .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

                        if sheetViewModel.selectedPetId == pet.petId {
                            Text("대표")
                                .font(.appScaledFont(for: .SemiBold, size: 10, relativeTo: .caption2))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.appYellow.opacity(0.18))
                                .clipShape(Capsule())
                        }

                        Spacer(minLength: 0)
                    }

                    Text(sheetViewModel.petDetailsText(for: pet))
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))

                    HStack(spacing: 8) {
                        Button("편집") {
                            editSheetViewModel = sheetViewModel.makeEditViewModel(for: pet)
                        }
                        .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("settings.petManagement.edit")

                        Button("대표로 지정") {
                            sheetViewModel.setPrimaryPet(pet.petId)
                        }
                        .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                        .disabled(sheetViewModel.selectedPetId == pet.petId)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("settings.petManagement.primary")

                        Button("비활성") {
                            sheetViewModel.setPetActive(pet.petId, isActive: false)
                        }
                        .buttonStyle(AppFilledButtonStyle(role: .destructive, fillsWidth: false))
                        .disabled(sheetViewModel.activePets.count <= 1)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("settings.petManagement.deactivate")
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .appCardSurface()
    }

    private var inactivePetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("비활성 반려견")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            ForEach(sheetViewModel.inactivePets, id: \.petId) { pet in
                VStack(alignment: .leading, spacing: 10) {
                    Text(pet.petName)
                        .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                        .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

                    Text(sheetViewModel.petDetailsText(for: pet))
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))

                    HStack(spacing: 8) {
                        Button("편집") {
                            editSheetViewModel = sheetViewModel.makeEditViewModel(for: pet)
                        }
                        .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("settings.petManagement.edit")

                        Button("다시 활성화") {
                            sheetViewModel.setPetActive(pet.petId, isActive: true)
                        }
                        .buttonStyle(AppFilledButtonStyle(role: .primary, fillsWidth: false))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("settings.petManagement.reactivate")
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .appCardSurface()
    }

    private var addPetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("반려견 추가")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            ProfileEditorImageSection(
                title: "새 반려견 프로필 이미지",
                subtitle: "앨범 또는 카메라에서 사진을 고를 수 있습니다.",
                remoteURL: nil,
                selectedImage: $sheetViewModel.newPetProfileImage,
                resetButtonTitle: "선택 취소",
                resetButtonEnabled: sheetViewModel.newPetProfileImage != nil,
                allowsCamera: true,
                onReset: {
                    sheetViewModel.newPetProfileImage = nil
                },
                onCameraUnavailable: {
                    sheetViewModel.errorMessage = "현재 기기에서는 카메라를 사용할 수 없습니다."
                }
            )

            ProfileEditorPetFieldsCard(
                title: "새 반려견 정보",
                subtitle: "이름은 필수, 상세 정보는 선택입니다.",
                petName: $sheetViewModel.newPetName,
                breed: $sheetViewModel.newBreed,
                ageYearsText: $sheetViewModel.newAgeYearsText,
                gender: $sheetViewModel.newGender,
                requiresPetName: true
            )

            Button(sheetViewModel.isSaving ? "추가 중..." : "반려견 추가") {
                Task {
                    await sheetViewModel.addPet()
                }
            }
            .disabled(sheetViewModel.isSaving)
            .buttonStyle(AppFilledButtonStyle(role: .primary))
            .frame(minHeight: 44)
            .accessibilityIdentifier("sheet.settings.petManagement.add")
        }
    }
}
