//
//  ProfileSettingsView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct ProfileSettingsView: View {
    @Binding var path: NavigationPath
    @StateObject var viewModel: SigningViewModel
    @State var imageSelect: Bool = false
    let onSignupCompleted: () -> Void

    init(
        path: Binding<NavigationPath>,
        viewModel: SigningViewModel,
        onSignupCompleted: @escaping () -> Void = {}
    ) {
        self._path = path
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onSignupCompleted = onSignupCompleted
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                TitleTextView(title: "프로필 사진",type: .MediumTitle, subTitle: "프로필 사진을 추가해주세요!")
                Button {
                    imageSelect.toggle()
                } label: {
                    Image(uiImage: viewModel.userProfile ?? .emptyImg)
                        .resizable()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .aspectRatio(contentMode: .fit)
                        .myCornerRadius(radius: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(viewModel.userProfile == nil ? Color.appTextLightGray : Color.appGreen, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                ProfileEditorUserFieldsCard(
                    userName: $viewModel.userName,
                    profileMessage: $viewModel.userProfileMessage
                )
                .padding(.horizontal, 16)

                NavigationLink(destination: {
                    PetProfileSettingView(path: $path, onSignupCompleted: onSignupCompleted).environmentObject(viewModel)
                }, label: { Text("다음 단계로") })
                .disabled(viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(
                    AppFilledButtonStyle(
                        role: viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .neutral : .primary
                    )
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .fullScreenCover(isPresented: $imageSelect, content: {
            ImagePicker(image: $viewModel.userProfile, type: .photoLibrary)
        })
    }
}
