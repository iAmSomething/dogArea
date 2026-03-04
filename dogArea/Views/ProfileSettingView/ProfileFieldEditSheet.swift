import SwiftUI
import UIKit
import Kingfisher

struct ProfileFieldEditSheet: View {
    private enum ProfileImageTarget {
        case user
        case pet
    }

    @Environment(\.dismiss) var dismiss
    @StateObject private var sheetViewModel: ProfileFieldEditSheetViewModel
    @State private var pickerTarget: ProfileImageTarget? = nil
    @State private var pickerSourceType: UIImagePickerController.SourceType? = nil
    let onSaved: (String) -> Void

    /// 프로필 편집 시트의 초기 상태를 구성합니다.
    /// - Parameters:
    ///   - viewModel: 사용자/반려견 정보와 저장 액션을 제공하는 설정 뷰모델입니다.
    ///   - onSaved: 저장 성공 시 사용자에게 보여줄 메시지를 전달하는 콜백입니다.
    init(viewModel: SettingViewModel, onSaved: @escaping (String) -> Void) {
        self.onSaved = onSaved
        _sheetViewModel = StateObject(wrappedValue: ProfileFieldEditSheetViewModel(provider: viewModel))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("사용자 기본 정보") {
                    TextField("사용자 이름", text: $sheetViewModel.userName)
                        .textInputAutocapitalization(.never)
                    TextField("프로필 메시지", text: $sheetViewModel.profileMessage)
                }
                Section("프로필 이미지") {
                    profileImageCard(
                        title: "사용자 프로필",
                        remoteURL: sheetViewModel.userProfileImageURL,
                        selectedImage: sheetViewModel.userProfileImage
                    )
                    imageActionRow(for: .user)
                }
                Section("\(sheetViewModel.selectedPetName) 이미지") {
                    profileImageCard(
                        title: "반려견 프로필",
                        remoteURL: sheetViewModel.petProfileImageURL,
                        selectedImage: sheetViewModel.petProfileImage
                    )
                    imageActionRow(for: .pet)
                }
                Section("반려견 (선택된 반려견 기준)") {
                    TextField("견종/믹스/기타 (선택)", text: $sheetViewModel.breed)
                    TextField("나이 (0~30)", text: $sheetViewModel.ageYearsText)
                        .keyboardType(.numberPad)
                    Picker("성별", selection: $sheetViewModel.gender) {
                        ForEach(PetGender.allCases, id: \.rawValue) { item in
                            Text(item.title).tag(item)
                        }
                    }
                }
                Section("반려견 캐리커처") {
                    Text("현재 상태: \(sheetViewModel.caricatureStatusText)")
                        .font(.appFont(for: .Light, size: 11))
                        .foregroundStyle(Color.appTextDarkGray)

                    Button(sheetViewModel.isGeneratingCaricature ? "생성 중..." : "캐리커처 생성/재생성") {
                        Task {
                            await sheetViewModel.requestCaricatureRegeneration()
                        }
                    }
                    .disabled(sheetViewModel.isGeneratingCaricature)

                    if let caricatureMessage = sheetViewModel.caricatureMessage {
                        Text(caricatureMessage)
                            .font(.appFont(for: .Regular, size: 12))
                            .foregroundStyle(Color.appTextDarkGray)
                    }
                }
                if let errorMessage = sheetViewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.appFont(for: .Regular, size: 12))
                            .foregroundStyle(Color.red)
                    }
                }
            }
            .navigationTitle("프로필 편집")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("sheet.settings.profileEdit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                    .accessibilityIdentifier("sheet.settings.profileEdit.cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(sheetViewModel.isSaving ? "저장 중..." : "저장") {
                        Task {
                            if await sheetViewModel.saveChanges() {
                                onSaved("프로필 정보를 저장했어요.")
                                dismiss()
                            }
                        }
                    }
                    .disabled(sheetViewModel.isSaving || sheetViewModel.isGeneratingCaricature)
                    .accessibilityIdentifier("sheet.settings.profileEdit.save")
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { pickerTarget != nil && pickerSourceType != nil },
                set: { isPresented in
                    if isPresented == false {
                        pickerTarget = nil
                        pickerSourceType = nil
                    }
                }
            )
        ) {
            if let pickerSourceType, let pickerTarget {
                ImagePicker(
                    image: pickerTarget == .user
                    ? $sheetViewModel.userProfileImage
                    : $sheetViewModel.petProfileImage,
                    type: pickerSourceType
                )
                .ignoresSafeArea()
            }
        }
    }

    /// 프로필 편집 시트에서 이미지 프리뷰 카드를 렌더링합니다.
    /// - Parameters:
    ///   - title: 카드 상단 라벨 텍스트입니다.
    ///   - remoteURL: 기존에 저장된 원격 이미지 URL입니다.
    ///   - selectedImage: 이번 편집에서 새로 선택된 로컬 이미지입니다.
    /// - Returns: 원격/로컬 이미지 우선순위를 반영한 미리보기 카드 뷰입니다.
    private func profileImageCard(title: String, remoteURL: String?, selectedImage: UIImage?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appScaledFont(for: .SemiBold, size: 13, relativeTo: .subheadline))
                .foregroundStyle(Color.appTextDarkGray)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 이미지 입력 경로(앨범/카메라/초기화) 버튼 행을 렌더링합니다.
    /// - Parameter target: 변경 대상 이미지 슬롯(사용자/반려견)입니다.
    /// - Returns: 이미지 입력 액션 버튼이 배치된 수평 스택 뷰입니다.
    private func imageActionRow(for target: ProfileImageTarget) -> some View {
        HStack(spacing: 8) {
            Button("앨범") {
                pickerTarget = target
                pickerSourceType = .photoLibrary
            }
            .buttonStyle(AppFilledButtonStyle(role: .secondary, fillsWidth: false))
            .frame(minHeight: 44)

            Button("카메라") {
                guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                    sheetViewModel.errorMessage = "현재 기기에서는 카메라를 사용할 수 없습니다."
                    return
                }
                pickerTarget = target
                pickerSourceType = .camera
            }
            .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
            .frame(minHeight: 44)

            Button("초기화") {
                if target == .user {
                    sheetViewModel.userProfileImage = nil
                } else {
                    sheetViewModel.petProfileImage = nil
                }
            }
            .buttonStyle(AppFilledButtonStyle(role: .neutral, fillsWidth: false))
            .frame(minHeight: 44)
        }
    }
}
