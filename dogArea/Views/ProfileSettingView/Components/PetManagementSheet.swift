import SwiftUI
import UIKit

struct PetManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingViewModel

    @State private var petName: String = ""
    @State private var breed: String = ""
    @State private var ageYearsText: String = ""
    @State private var gender: PetGender = .unknown
    @State private var petProfileImage: UIImage? = nil
    @State private var imageSelectPresented: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    activePetCard

                    if viewModel.inactivePets.isEmpty == false {
                        inactivePetCard
                    }

                    addPetCard

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 16)
                    }

                    if let successMessage {
                        Text(successMessage)
                            .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                            .foregroundStyle(Color.appGreen)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color.appTabScaffoldBackground.ignoresSafeArea())
            .navigationTitle("반려견 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $imageSelectPresented) {
            ImagePicker(image: $petProfileImage, type: .photoLibrary)
                .ignoresSafeArea()
        }
    }

    private var activePetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("활성 반려견")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            ForEach(viewModel.activePets, id: \.petId) { pet in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(pet.petName)
                            .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                        if viewModel.selectedPetId == pet.petId {
                            Text("대표")
                                .font(.appScaledFont(for: .SemiBold, size: 10, relativeTo: .caption2))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.appYellow.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        Spacer(minLength: 0)
                    }

                    Text(viewModel.petDetailsText(for: pet))
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))

                    HStack(spacing: 8) {
                        Button("대표로 지정") {
                            applyImmediateAction {
                                try viewModel.setPrimaryPet(pet.petId)
                                successMessage = "대표 반려견을 변경했어요."
                            }
                        }
                        .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                        .disabled(viewModel.selectedPetId == pet.petId)
                        .frame(minHeight: 44)

                        Button("비활성") {
                            applyImmediateAction {
                                try viewModel.setPetActive(pet.petId, isActive: false)
                                successMessage = "반려견을 비활성 목록으로 이동했어요."
                            }
                        }
                        .buttonStyle(AppFilledButtonStyle(role: .destructive, fillsWidth: false))
                        .disabled(viewModel.activePets.count <= 1)
                        .frame(minHeight: 44)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .appCardSurface()
    }

    private var inactivePetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("비활성 반려견")
                .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))

            ForEach(viewModel.inactivePets, id: \.petId) { pet in
                VStack(alignment: .leading, spacing: 8) {
                    Text(pet.petName)
                        .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                    Text(viewModel.petDetailsText(for: pet))
                        .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .body))
                        .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                    Button("다시 활성화") {
                        applyImmediateAction {
                            try viewModel.setPetActive(pet.petId, isActive: true)
                            successMessage = "반려견을 다시 활성화했어요."
                        }
                    }
                    .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                    .frame(minHeight: 44)
                }
                .padding(14)
                .background(Color.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .appCardSurface()
    }

    private var addPetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("반려견 추가")
                    .font(.appScaledFont(for: .SemiBold, size: 18, relativeTo: .headline))
                Spacer(minLength: 0)
                Button("사진 선택") {
                    imageSelectPresented = true
                }
                .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
                .frame(minHeight: 44)
            }

            ProfileEditorPetFieldsCard(
                title: "새 반려견 정보",
                subtitle: "이름은 필수, 상세 정보는 선택입니다.",
                petName: $petName,
                breed: $breed,
                ageYearsText: $ageYearsText,
                gender: $gender,
                requiresPetName: true
            )

            Button(isSaving ? "추가 중..." : "반려견 추가") {
                Task {
                    await addPet()
                }
            }
            .disabled(isSaving)
            .buttonStyle(AppFilledButtonStyle(role: .primary))
            .frame(minHeight: 44)
        }
        .appCardSurface()
    }

    /// 새 반려견 입력값을 저장하고 성공 시 폼을 초기화합니다.
    /// - Returns: 없음. 처리 결과는 로컬 메시지 상태에 반영됩니다.
    @MainActor
    private func addPet() async {
        errorMessage = nil
        successMessage = nil
        isSaving = true
        defer { isSaving = false }

        let result = await viewModel.addPet(
            petName: petName,
            breed: breed,
            ageYearsText: ageYearsText,
            gender: gender,
            petProfileImage: petProfileImage
        )
        switch result {
        case .success:
            petName = ""
            breed = ""
            ageYearsText = ""
            gender = .unknown
            petProfileImage = nil
            successMessage = "반려견을 추가했어요."
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    /// 동기 액션을 실행하고 공통 에러 메시지 상태를 처리합니다.
    /// - Parameter action: 실행할 반려견 관리 작업입니다.
    private func applyImmediateAction(_ action: () throws -> Void) {
        errorMessage = nil
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
