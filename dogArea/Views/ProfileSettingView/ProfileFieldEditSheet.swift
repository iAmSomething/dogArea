import SwiftUI

struct ProfileFieldEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var sheetViewModel: ProfileFieldEditSheetViewModel
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
                Section("사용자") {
                    TextField("프로필 메시지", text: $sheetViewModel.profileMessage)
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
                    Button("저장") {
                        if sheetViewModel.saveChanges() {
                            onSaved("프로필 정보를 저장했어요.")
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("sheet.settings.profileEdit.save")
                }
            }
        }
    }
}
