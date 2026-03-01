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

                VStack(alignment: .leading, spacing: 10) {
                    TitleTextView(title: "사용자 이름", type: .MediumTitle, subTitle: "사용자 이름을 입력해주세요!")
                    TextField("사용자 이름을 입력해주세요", text: $viewModel.userName)
                        .appInputField(validity: viewModel.userName.isEmpty == false)

                    TitleTextView(title: "프로필 메시지", type: .MediumTitle, subTitle: "산책 스타일을 한 줄로 소개해보세요! (선택)")
                    TextField("예: 아침 산책을 좋아해요", text: $viewModel.userProfileMessage)
                        .appInputField()

                    NavigationLink(destination: {
                        PetProfileSettingView(path: $path, onSignupCompleted: onSignupCompleted).environmentObject(viewModel)
                    }, label: { Text("다음 단계로") })
                    .disabled(viewModel.userName.isEmpty)
                    .buttonStyle(AppFilledButtonStyle(role: viewModel.userName.isEmpty ? .neutral : .primary))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .appCardSurface()
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .fullScreenCover(isPresented: $imageSelect, content: {
            ImagePicker(image: $viewModel.userProfile, type: .photoLibrary)
        })
    }
    
}
