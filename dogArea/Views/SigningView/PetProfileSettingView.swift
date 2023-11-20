//
//  PetProfileSettingView.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import SwiftUI

struct PetProfileSettingView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: SigningViewModel
    @Binding var path: NavigationPath
    @State var imageSelect: Bool = false
    var body: some View {
        VStack {
            TitleTextView(title: "강아지 사진",type: .MediumTitle, subTitle: "강아지 사진을 추가해주세요!")
            Image(uiImage: viewModel.petProfile ?? .emptyImg)
                .resizable()
                .frame(maxWidth: 200, maxHeight: 200)
                .aspectRatio(contentMode: .fit)
                .myCornerRadius(radius: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(!viewModel.petProfile.isNil ? Color.appGreen : Color.appRed, lineWidth: 0.8)
                        .foregroundStyle(Color.clear)
                    
                ).onTapGesture {
                    imageSelect.toggle()
                }
            UnderLine()
            TitleTextView(title: "강아지 이름", type: .MediumTitle, subTitle: "강아지 이름을 입력해주세요!")
            HStack {
                TextField("강아지 이름을 입력해주세요", text: $viewModel.petName)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(viewModel.petName != "" ? Color.appGreen : Color.appRed, lineWidth: 0.8)
                    )
                    .padding(.horizontal)
            }
            Spacer()
            Button(action: {
                viewModel.setValue()
                path = .init()
            }, label: {
                Text("회원 가입하기")
            })
            .disabled(viewModel.petName.isEmpty)
                .padding()
                .background(viewModel.petName.isEmpty ? Color.appTextLightGray :Color.appGreen)
                .myCornerRadius(radius: 15)
        }.fullScreenCover(isPresented: $imageSelect, content: {
            ImagePicker(image: $viewModel.petProfile, type: .photoLibrary)
        }).overlay(content: {
            if viewModel.loading == .loading {
                LoadingView()
            }
        })
    }
}

