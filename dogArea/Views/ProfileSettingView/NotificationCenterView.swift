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
    @State private var isProfileEditPresented: Bool = false
    @State private var toastMessage: String? = nil
       var body: some View {
           VStack {
               TitleTextView(title: "사용자 정보", subTitle: "사용자의 정보를 알려드립니다.")
               HStack {
                   Spacer()
                   Button(action: {
                       isProfileEditPresented = true
                   }, label: {
                       Text("프로필 편집")
                           .font(.appFont(for: .Regular, size: 13))
                           .padding(.horizontal, 10)
                           .padding(.vertical, 6)
                           .background(Color.appYellowPale)
                           .cornerRadius(8)
                   })
                   .padding(.horizontal, 16)
               }
               HStack {
                   UserProfileImageView()
                       .environmentObject(viewModel)
                       .padding(.trailing, 20)
                   VStack(alignment: .leading) {
                       Text("\(viewModel.userInfo?.name ?? "산책꾼")")
                           .font(.appFont(for: .SemiBold, size: 20))
                       if let profileMessage = viewModel.userInfo?.profileMessage,
                          profileMessage.isEmpty == false {
                           Text(profileMessage)
                               .font(.appFont(for: .Regular, size: 13))
                               .foregroundStyle(Color.appTextDarkGray)
                       }
                       Text("가입 정보: \(viewModel.userInfo?.createdAt.createdAtTimeYYMMDD ?? "")")
                           .font(.appFont(for: .Light, size: 11))
                           .foregroundStyle(Color.appTextDarkGray)
                   }
                   Spacer()
               }
               if let season = viewModel.seasonProfileSummary {
                   seasonSummaryCard(summary: season)
                       .padding(.horizontal, 16)
               }
               UnderLine()
               TitleTextView(title: "강아지 정보",type: .MediumTitle, subTitle: "강아지를 소개할게요")
               if viewModel.pets.isEmpty == false {
                   ScrollView(.horizontal, showsIndicators: false) {
                       HStack(spacing: 8) {
                           ForEach(viewModel.pets, id: \.petId) { pet in
                               Text(pet.petName)
                                   .font(.appFont(for: .Regular, size: 13))
                                   .padding(.horizontal, 10)
                                   .padding(.vertical, 6)
                                   .background(viewModel.selectedPetId == pet.petId ? Color.appYellow : Color.appYellowPale)
                                   .cornerRadius(8)
                                   .onTapGesture {
                                       viewModel.selectPet(pet.petId)
                                   }
                           }
                       }.padding(.horizontal, 16)
                   }
               }
               HStack {
                   PetProfileImageView()
                       .environmentObject(viewModel)
                       .padding(.trailing, 20)
                   VStack(alignment: .leading) {
                       Text("\(viewModel.selectedPet?.petName ?? "강아지")")
                           .font(.appFont(for: .SemiBold, size: 20))
                       Text(petDetailsText(viewModel.selectedPet))
                           .font(.appFont(for: .Regular, size: 12))
                           .foregroundStyle(Color.appTextDarkGray)
                       if let status = viewModel.selectedPet?.caricatureStatus {
                           Text("캐리커처 상태: \(status.rawValue)")
                               .font(.appFont(for: .Light, size: 11))
                               .foregroundStyle(Color.appTextDarkGray)
                       }
                   }
                   Spacer()
               }
               if viewModel.pets.count > 1 {
                   HStack {
                       Text("현재 함께 사는 강아지")
                           .font(.appFont(for: .Light, size: 12))
                           .foregroundStyle(Color.appTextDarkGray)
                       Spacer()
                   }
                   Picker("대표 강아지", selection: Binding<String>(
                    get: { viewModel.selectedPetId.isEmpty == false ? viewModel.selectedPetId : (viewModel.pets.first?.petId ?? "") },
                    set: { viewModel.selectPet($0) }
                   )) {
                       ForEach(viewModel.pets, id: \.id) { pet in
                           Text(pet.petName).tag(pet.petId)
                       }
                   }
                   .pickerStyle(.menu)
               }
               Spacer()
           }
           .onAppear {
               viewModel.reloadUserInfo()
           }
           .sheet(isPresented: $isProfileEditPresented) {
               ProfileFieldEditSheet(viewModel: viewModel) { message in
                   toastMessage = message
                   DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                       toastMessage = nil
                   }
               }
           }
           .overlay {
               if let toastMessage {
                   SimpleMessageView(message: toastMessage)
                       .transition(.opacity)
               }
           }
       }

    private func seasonSummaryCard(summary: SeasonProfileSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("시즌 진행 현황")
                .font(.appFont(for: .SemiBold, size: 13))
            Text("랭크 \(summary.rankTier.title) · 점수 \(summary.score)pt")
                .font(.appFont(for: .Regular, size: 12))
                .foregroundStyle(Color.appTextDarkGray)
            Text("주차 \(summary.weekKey) · 기여 \(summary.contributionCount)회")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.appYellowPale.opacity(0.55))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.appTextLightGray, lineWidth: 0.4)
        )
    }

    private func petDetailsText(_ pet: PetInfo?) -> String {
        guard let pet else { return "품종/나이/성별 미입력" }
        let breed = pet.breed.flatMap { $0.isEmpty ? nil : $0 } ?? "품종 미입력"
        let age = pet.ageYears.map { "\($0)세" } ?? "나이 미입력"
        let gender = pet.gender.title
        return "\(breed) · \(age) · \(gender)"
    }
}

struct ProfileFieldEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SettingViewModel
    let onSaved: (String) -> Void

    @State private var profileMessage: String
    @State private var breed: String
    @State private var ageYearsText: String
    @State private var gender: PetGender
    @State private var errorMessage: String? = nil

    init(viewModel: SettingViewModel, onSaved: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.onSaved = onSaved
        _profileMessage = State(initialValue: viewModel.userInfo?.profileMessage ?? "")
        _breed = State(initialValue: viewModel.selectedPet?.breed ?? "")
        _ageYearsText = State(initialValue: viewModel.selectedPet?.ageYears.map(String.init) ?? "")
        _gender = State(initialValue: viewModel.selectedPet?.gender ?? .unknown)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("사용자") {
                    TextField("프로필 메시지", text: $profileMessage)
                }
                Section("반려견 (선택된 반려견 기준)") {
                    TextField("품종", text: $breed)
                    TextField("나이 (0~30)", text: $ageYearsText)
                        .keyboardType(.numberPad)
                    Picker("성별", selection: $gender) {
                        ForEach(PetGender.allCases, id: \.rawValue) { item in
                            Text(item.title).tag(item)
                        }
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.appFont(for: .Regular, size: 12))
                            .foregroundStyle(Color.red)
                    }
                }
            }
            .navigationTitle("프로필 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        let result = viewModel.updateProfileDetails(
                            profileMessage: profileMessage,
                            breed: breed,
                            ageYearsText: ageYearsText,
                            gender: gender
                        )
                        switch result {
                        case .success:
                            onSaved("프로필 정보를 저장했어요.")
                            dismiss()
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
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
        if let url = viewModel.selectedPet?.caricatureURL ?? viewModel.selectedPet?.petProfile {
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
