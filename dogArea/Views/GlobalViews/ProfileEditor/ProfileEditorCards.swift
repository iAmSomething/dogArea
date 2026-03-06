import SwiftUI

struct ProfileEditorUserFieldsCard: View {
    @Binding var userName: String
    @Binding var profileMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TitleTextView(title: "사용자 기본 정보", type: .MediumTitle, subTitle: "이름은 필수, 프로필 메시지는 선택입니다.")
            TextField("사용자 이름", text: $userName)
                .appInputField(validity: userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                .accessibilityIdentifier("settings.profile.field.userName")
            TextField("프로필 메시지", text: $profileMessage)
                .appInputField()
                .accessibilityIdentifier("settings.profile.field.profileMessage")
        }
        .padding(.horizontal, 16)
        .appCardSurface()
    }
}

struct ProfileEditorPetFieldsCard: View {
    let title: String
    let subtitle: String
    @Binding var petName: String
    @Binding var breed: String
    @Binding var ageYearsText: String
    @Binding var gender: PetGender
    let requiresPetName: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TitleTextView(title: title, type: .MediumTitle, subTitle: subtitle)
            TextField("강아지 이름", text: $petName)
                .appInputField(validity: requiresPetName == false || petName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                .accessibilityIdentifier("settings.profile.field.petName")
            TextField("견종/믹스/기타 (선택)", text: $breed)
                .appInputField()
                .accessibilityIdentifier("settings.profile.field.breed")
            TextField("나이 (0~30)", text: $ageYearsText)
                .keyboardType(.numberPad)
                .appInputField()
                .accessibilityIdentifier("settings.profile.field.ageYears")
            Picker("성별", selection: $gender) {
                ForEach(PetGender.allCases, id: \.rawValue) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.profile.field.gender")
        }
        .padding(.horizontal, 16)
        .appCardSurface()
    }
}
