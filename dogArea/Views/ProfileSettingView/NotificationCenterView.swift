//
//  NotificationCenterView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI
import Kingfisher
struct NotificationCenterView: View {
    @StateObject var viewModel = SettingViewModel()
    @EnvironmentObject var loading: LoadingViewModel
       var body: some View {
           VStack {
               TitleTextView(title: "사용자 정보", subTitle: "사용자의 정보를 알려드립니다.")
               HStack {
                   UserProfileImageView()
                       .environmentObject(viewModel)
                       .padding(.trailing, 20)
                   VStack(alignment: .leading) {
                       Text("\(viewModel.userInfo?.name ?? "산책꾼")")
                           .font(.appFont(for: .SemiBold, size: 20))
                       Text("가입 정보: \(viewModel.userInfo?.createdAt.createdAtTimeYYMMDD ?? "")")
                           .font(.appFont(for: .Light, size: 11))
                           .foregroundStyle(Color.appTextDarkGray)
                   }
                   Spacer()
               }
               UnderLine()
               TitleTextView(title: "강아지 정보",type: .MediumTitle, subTitle: "강아지를 소개할게요")
               HStack {
                   PetProfileImageView()
                       .environmentObject(viewModel)
                       .padding(.trailing, 20)
                   VStack(alignment: .leading) {
                       Text("\(viewModel.userInfo?.pet.first?.petName ?? "강아지")")
                           .font(.appFont(for: .SemiBold, size: 20))
                   }
                   Spacer()
               }
               Spacer()
           }
       }
}
struct ImageView: View {
    let image: UIImage?
    var body: some View {
        if let image = image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Text("프로필 이미지")
                .foregroundColor(.gray)
        }
    }
}

#Preview {
  NotificationCenterView()
}

struct UserProfileImageView: View {
    @EnvironmentObject var viewModel: SettingViewModel
    var body: some View {
        if let url = viewModel.userInfo?.profile {
            KFImage(URL(string: url))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 100, maxHeight: 100)
                .myCornerRadius(radius: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.appTextDarkGray, lineWidth: 0.8)
                        .foregroundStyle(Color.clear)
                    
                )
                .padding()
        } else {
            Image(uiImage: .emptyImg)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 100, maxHeight: 100)
                .myCornerRadius(radius: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.appTextDarkGray, lineWidth: 0.8)
                        .foregroundStyle(Color.clear)
                    
                )
                .padding()
        }
    }
}
struct PetProfileImageView: View {
    @EnvironmentObject var viewModel: SettingViewModel
    var body: some View {
        if let url = viewModel.userInfo?.pet.first?.petProfile {
            KFImage(URL(string: url))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 100, maxHeight: 100)
                .myCornerRadius(radius: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.appTextDarkGray, lineWidth: 0.8)
                        .foregroundStyle(Color.clear)
                    
                )
                .padding()
        } else {
            Image(uiImage: .emptyImg)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 100, maxHeight: 100)
                .myCornerRadius(radius: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.appTextDarkGray, lineWidth: 0.8)
                        .foregroundStyle(Color.clear)
                    
                )
                .padding()
        }
    }
}
