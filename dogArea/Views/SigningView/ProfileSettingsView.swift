//
//  ProfileSettingsView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.colorScheme) var scheme
    @Binding var path: NavigationPath
    @StateObject var viewModel: SigningViewModel
    @State var imageSelect: Bool = false
    var body: some View {
        VStack {
            TitleTextView(title: "프로필 사진",type: .MediumTitle, subTitle: "프로필 사진을 추가해주세요!")
            Image(uiImage: viewModel.userProfile ?? .emptyImg)
                .resizable()
                .frame(maxWidth: 200, maxHeight: 200)
                .aspectRatio(contentMode: .fit)
                .myCornerRadius(radius: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(!viewModel.userProfile.isNil ? Color.appColor(type: .appGreen, scheme: scheme) : Color.appColor(type: .appRed, scheme: scheme), lineWidth: 0.8)
                        .foregroundStyle(Color.clear)
                    
                ).onTapGesture {
                    imageSelect.toggle()
                }

            UnderLine()
            TitleTextView(title: "사용자 이름", type: .MediumTitle, subTitle: "사용자 이름을 입력해주세요!")
            HStack {
                TextField("사용자 이름을 입력해주세요", text: $viewModel.userName)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(viewModel.userName != "" ? Color.appColor(type: .appGreen, scheme: scheme) : Color.appColor(type: .appRed, scheme: scheme), lineWidth: 0.8)
                    )
                    .padding(.horizontal)
            }
            Spacer()
            NavigationLink(destination: {
                PetProfileSettingView(path: $path).environmentObject(viewModel)}
                           , label: {Text("다음 단계로")})
            .disabled(viewModel.userName.isEmpty)
            .padding()
            .background(viewModel.userName.isEmpty ? Color.appColor(type: .appTextDarkGray, scheme: scheme) : Color.appColor(type: .appGreen, scheme: scheme))
            .myCornerRadius(radius: 15)
        }.fullScreenCover(isPresented: $imageSelect, content: {
            ImagePicker(image: $viewModel.userProfile, type: .photoLibrary)
        })
    }
    
}
