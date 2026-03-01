//
//  NotificationCenterView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI
import Kingfisher
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif
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
                       if let season = viewModel.seasonProfileSummary {
                           Text("Season \(season.rankTier.title)")
                               .font(.appFont(for: .SemiBold, size: 11))
                               .padding(.horizontal, 8)
                               .padding(.vertical, 4)
                               .background(SeasonProfileFrameStyle.style(for: season.rankTier).fill.opacity(0.2))
                               .cornerRadius(8)
                       }
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
            Text("프로필 프레임: \(summary.rankTier.title)")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(SeasonProfileFrameStyle.style(for: summary.rankTier).fill.opacity(0.2))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(SeasonProfileFrameStyle.style(for: summary.rankTier).stroke, lineWidth: 0.8)
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
    @State private var caricatureMessage: String? = nil

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
                Section("반려견 캐리커처") {
                    Text("현재 상태: \(viewModel.selectedPet?.caricatureStatus?.rawValue ?? "none")")
                        .font(.appFont(for: .Light, size: 11))
                        .foregroundStyle(Color.appTextDarkGray)

                    Button(viewModel.isCaricatureGenerating ? "생성 중..." : "캐리커처 생성/재생성") {
                        caricatureMessage = nil
                        Task {
                            let message = await viewModel.regenerateSelectedPetCaricature()
                            await MainActor.run {
                                caricatureMessage = message
                            }
                        }
                    }
                    .disabled(viewModel.isCaricatureGenerating)

                    if let caricatureMessage {
                        Text(caricatureMessage)
                            .font(.appFont(for: .Regular, size: 12))
                            .foregroundStyle(Color.appTextDarkGray)
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
        let rankTier = viewModel.seasonProfileSummary?.rankTier
        let frameStyle = SeasonProfileFrameStyle.style(for: rankTier)
        if let url = viewModel.userInfo?.profile {
            KFImage(URL(string: url))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 100, maxHeight: 100)
                .myCornerRadius(radius: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(frameStyle.stroke, lineWidth: 1.4)
                        .foregroundStyle(Color.clear)
                )
                .overlay(alignment: .topTrailing) {
                    if let rankTier {
                        Text(rankTier.title)
                            .font(.appFont(for: .SemiBold, size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(frameStyle.fill.opacity(0.92))
                            .cornerRadius(7)
                            .offset(x: 6, y: -6)
                    }
                }
                .padding()
        } else {
            Image(uiImage: .emptyImg)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 100, maxHeight: 100)
                .myCornerRadius(radius: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(frameStyle.stroke, lineWidth: 1.4)
                        .foregroundStyle(Color.clear)
                )
                .overlay(alignment: .topTrailing) {
                    if let rankTier {
                        Text(rankTier.title)
                            .font(.appFont(for: .SemiBold, size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(frameStyle.fill.opacity(0.92))
                            .cornerRadius(7)
                            .offset(x: 6, y: -6)
                    }
                }
                .padding()
        }
    }
}
struct PetProfileImageView: View {
    @EnvironmentObject var viewModel: SettingViewModel
    var body: some View {
        let rankTier = viewModel.seasonProfileSummary?.rankTier
        let frameStyle = SeasonProfileFrameStyle.style(for: rankTier)
        if let url = viewModel.selectedPet?.caricatureURL ?? viewModel.selectedPet?.petProfile {
            KFImage(URL(string: url))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 100, maxHeight: 100)
                .myCornerRadius(radius: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(frameStyle.stroke, lineWidth: 1.4)
                        .foregroundStyle(Color.clear)
                )
                .overlay(alignment: .topTrailing) {
                    if let rankTier {
                        Text(rankTier.title)
                            .font(.appFont(for: .SemiBold, size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(frameStyle.fill.opacity(0.92))
                            .cornerRadius(7)
                            .offset(x: 6, y: -6)
                    }
                }
                .padding()
        } else {
            Image(uiImage: .emptyImg)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 100, maxHeight: 100)
                .myCornerRadius(radius: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(frameStyle.stroke, lineWidth: 1.4)
                        .foregroundStyle(Color.clear)
                )
                .overlay(alignment: .topTrailing) {
                    if let rankTier {
                        Text(rankTier.title)
                            .font(.appFont(for: .SemiBold, size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(frameStyle.fill.opacity(0.92))
                            .cornerRadius(7)
                            .offset(x: 6, y: -6)
                    }
                }
                .padding()
        }
    }
}

private struct SeasonProfileFrameStyle {
    let stroke: Color
    let fill: Color

    static func style(for rankTier: SeasonRankTier?) -> SeasonProfileFrameStyle {
        switch rankTier {
        case .some(.platinum):
            return .init(stroke: Color.appRed, fill: Color.appRed)
        case .some(.gold):
            return .init(stroke: Color.appYellow, fill: Color.appYellow)
        case .some(.silver):
            return .init(stroke: Color.appTextLightGray, fill: Color.appTextLightGray)
        case .some(.bronze):
            return .init(stroke: Color.appPeach, fill: Color.appPeach)
        case .some(.rookie):
            return .init(stroke: Color.appGreen, fill: Color.appGreen)
        case .none:
            return .init(stroke: Color.appTextDarkGray, fill: Color.appYellowPale)
        }
    }
}

struct RivalTabView: View {
    @EnvironmentObject private var authFlow: AuthFlowCoordinator
    @StateObject private var viewModel = RivalTabViewModel()
    @State private var isConsentSheetPresented: Bool = false

    let onOpenMap: () -> Void
    let onOpenSettings: () -> Void

    init(
        onOpenMap: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.onOpenMap = onOpenMap
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                TitleTextView(title: "라이벌", subTitle: "근처 산책 열기를 익명으로 확인해요")
                statusBadgeRow
                privacyCard
                hotspotCard
                leaderboardSkeletonCard
                footerButtons
            }
            .padding(.bottom, 24)
        }
        .background(Color.appYellowPale.opacity(0.35))
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .sheet(isPresented: $isConsentSheetPresented) {
            consentSheet
        }
        .overlay(alignment: .top) {
            if let message = viewModel.toastMessage {
                SimpleMessageView(message: message)
                    .padding(.top, 8)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            viewModel.clearToast()
                        }
                    }
            }
        }
    }

    private var statusBadgeRow: some View {
        HStack(spacing: 8) {
            rivalBadge(
                text: viewModel.sharingBadgeText,
                color: viewModel.sharingBadgeColor
            )
            rivalBadge(
                text: viewModel.permissionBadgeText,
                color: viewModel.permissionBadgeColor
            )
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("익명 위치 공유")
                .font(.appFont(for: .SemiBold, size: 20))
            Text("닉네임/강아지명/정밀 좌표는 노출되지 않아요")
                .font(.appFont(for: .Regular, size: 13))
                .foregroundStyle(Color.appTextDarkGray)

            if viewModel.screenState == .guestLocked {
                Button("로그인하고 라이벌 시작") {
                    _ = authFlow.requestAccess(feature: .nearbySocial)
                }
                .font(.appFont(for: .SemiBold, size: 13))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.appYellow)
                .cornerRadius(8)
            } else if viewModel.locationSharingEnabled {
                Button(viewModel.isWorking ? "처리 중..." : "공유 중지") {
                    viewModel.disableSharing()
                }
                .disabled(viewModel.isWorking)
                .font(.appFont(for: .SemiBold, size: 13))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.appTextLightGray)
                .cornerRadius(8)
            } else {
                Button("익명 공유 시작") {
                    switch viewModel.permissionState {
                    case .authorized:
                        isConsentSheetPresented = true
                    case .notDetermined:
                        viewModel.requestLocationPermission()
                    case .denied:
                        viewModel.openSystemSettings()
                    }
                }
                .font(.appFont(for: .SemiBold, size: 13))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.appYellow)
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.appTextDarkGray.opacity(0.25), lineWidth: 0.8)
        )
        .padding(.horizontal, 16)
    }

    private var hotspotCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("근처 익명 핫스팟")
                .font(.appFont(for: .SemiBold, size: 20))

            switch viewModel.screenState {
            case .guestLocked:
                Text("회원 가입 후 이용할 수 있어요")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
            case .permissionRequired:
                Text("근처 익명 핫스팟을 보려면 위치 권한이 필요해요")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Button("설정 열기") {
                    viewModel.openSystemSettings()
                }
                .font(.appFont(for: .SemiBold, size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale)
                .cornerRadius(8)
            case .consentRequired:
                Text("익명 공유 동의 후 핫스팟을 볼 수 있어요")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
            case .loading:
                ProgressView()
            case .ready, .offlineCached:
                Text("활성 핫스팟 \(viewModel.hotspots.count)개")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Text("최고 강도: \(viewModel.maxIntensityText)")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Text("마지막 업데이트: \(viewModel.lastUpdatedText)")
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
                HStack(spacing: 8) {
                    Button(viewModel.isWorking ? "새로고침 중..." : "새로고침") {
                        viewModel.refreshHotspots(force: true)
                    }
                    .disabled(viewModel.isWorking)
                    .font(.appFont(for: .SemiBold, size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appYellowPale)
                    .cornerRadius(8)

                    Button("지도에서 보기") {
                        onOpenMap()
                    }
                    .font(.appFont(for: .SemiBold, size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appYellow)
                    .cornerRadius(8)
                }
            case .offlineEmpty:
                Text("네트워크 연결 후 다시 시도해주세요")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Button("다시 시도") {
                    viewModel.refreshHotspots(force: true)
                }
                .font(.appFont(for: .SemiBold, size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale)
                .cornerRadius(8)
            case .errorRetryable:
                Text("일시적으로 불안정해요. 잠시 후 다시 시도해주세요.")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Button("다시 시도") {
                    viewModel.refreshHotspots(force: true)
                }
                .font(.appFont(for: .SemiBold, size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale)
                .cornerRadius(8)
            case .empty:
                Text("근처 활성 핫스팟이 아직 없어요")
                    .font(.appFont(for: .Regular, size: 12))
                    .foregroundStyle(Color.appTextDarkGray)
                Button("새로고침") {
                    viewModel.refreshHotspots(force: true)
                }
                .font(.appFont(for: .SemiBold, size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale)
                .cornerRadius(8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.appTextDarkGray.opacity(0.25), lineWidth: 0.8)
        )
        .padding(.horizontal, 16)
    }

    private var leaderboardSkeletonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("주간 라이벌 요약")
                    .font(.appFont(for: .SemiBold, size: 20))
                Spacer()
                Text("준비 중")
                    .font(.appFont(for: .SemiBold, size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appTextLightGray.opacity(0.35))
                    .cornerRadius(8)
            }
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.appTextLightGray.opacity(0.3))
                .frame(height: 14)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.appTextLightGray.opacity(0.3))
                .frame(height: 14)
            Button("전체 보기") {
                viewModel.showToast("리더보드는 다음 단계에서 열립니다.")
            }
            .font(.appFont(for: .SemiBold, size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.appYellowPale)
            .cornerRadius(8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.appTextDarkGray.opacity(0.25), lineWidth: 0.8)
        )
        .padding(.horizontal, 16)
    }

    private var footerButtons: some View {
        Button("설정에서 상세 관리") {
            onOpenSettings()
        }
        .font(.appFont(for: .SemiBold, size: 12))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.appYellowPale)
        .cornerRadius(8)
    }

    private var consentSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("익명 위치 공유 동의")
                .font(.appFont(for: .SemiBold, size: 22))
            Text("닉네임/강아지명/정밀 좌표는 표시되지 않고, 10분 TTL 집계로만 사용돼요.")
                .font(.appFont(for: .Regular, size: 13))
                .foregroundStyle(Color.appTextDarkGray)
            Text("언제든 라이벌 탭에서 공유를 끌 수 있어요.")
                .font(.appFont(for: .Regular, size: 13))
                .foregroundStyle(Color.appTextDarkGray)

            HStack(spacing: 10) {
                Button("취소") {
                    isConsentSheetPresented = false
                }
                .font(.appFont(for: .SemiBold, size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appYellowPale)
                .cornerRadius(8)

                Button(viewModel.isWorking ? "처리 중..." : "동의하고 시작") {
                    isConsentSheetPresented = false
                    viewModel.enableSharingWithConsent()
                }
                .disabled(viewModel.isWorking)
                .font(.appFont(for: .SemiBold, size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appYellow)
                .cornerRadius(8)
            }
            Spacer()
        }
        .padding(16)
        .presentationDetents([.medium])
    }

    private func rivalBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.appFont(for: .SemiBold, size: 11))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.25))
            .cornerRadius(8)
    }
}

@MainActor
final class RivalTabViewModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    enum PermissionState {
        case notDetermined
        case authorized
        case denied
    }

    enum ScreenState {
        case guestLocked
        case permissionRequired
        case consentRequired
        case loading
        case ready
        case empty
        case offlineCached
        case offlineEmpty
        case errorRetryable
    }

    @Published private(set) var permissionState: PermissionState = .notDetermined
    @Published private(set) var screenState: ScreenState = .guestLocked
    @Published private(set) var locationSharingEnabled: Bool = false
    @Published private(set) var hotspots: [NearbyHotspotDTO] = []
    @Published private(set) var isWorking: Bool = false
    @Published private(set) var lastUpdatedText: String = "-"
    @Published private(set) var maxIntensityText: String = "없음"
    @Published var toastMessage: String? = nil

    private let nearbyService: NearbyPresenceServiceProtocol
    private let preferenceStore: MapPreferenceStoreProtocol
    private let locationManager: CLLocationManager
    private let sessionProvider: () -> AppSessionState
    private let locationSharingKey = "nearby.locationSharingEnabled"
    private var pollingTimer: Timer? = nil
    private var lastRefreshAt: Date = .distantPast

    /// 라이벌 탭 상태를 제어하는 뷰모델을 초기화합니다.
    init(
        nearbyService: NearbyPresenceServiceProtocol = NearbyPresenceService(),
        preferenceStore: MapPreferenceStoreProtocol = DefaultMapPreferenceStore.shared,
        locationManager: CLLocationManager = CLLocationManager(),
        sessionProvider: @escaping () -> AppSessionState = { AppFeatureGate.currentSession() }
    ) {
        self.nearbyService = nearbyService
        self.preferenceStore = preferenceStore
        self.locationManager = locationManager
        self.sessionProvider = sessionProvider
        super.init()
    }

    deinit {
        pollingTimer?.invalidate()
    }

    /// 탭 진입 시 권한/공유 상태를 불러오고 폴링을 시작합니다.
    func start() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
        locationSharingEnabled = preferenceStore.bool(forKey: locationSharingKey, default: false)
        updatePermissionState()
        refreshViewState()
        startPollingIfNeeded()
        refreshHotspots(force: true)
    }

    /// 탭 이탈 시 폴링/위치 업데이트를 중단합니다.
    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        locationManager.stopUpdatingLocation()
    }

    /// 위치 권한 요청을 수행합니다.
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 동의 시트 완료 후 익명 공유를 활성화합니다.
    func enableSharingWithConsent() {
        guard currentUserId != nil else {
            showToast("회원 전용 기능입니다. 로그인 후 다시 시도해주세요.")
            refreshViewState()
            return
        }

        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await nearbyService.setVisibility(userId: currentUserId ?? "", enabled: true)
                preferenceStore.set(true, forKey: locationSharingKey)
                locationSharingEnabled = true
                showToast("익명 공유가 시작됐어요")
                refreshViewState()
                refreshHotspots(force: true)
            } catch {
                preferenceStore.set(false, forKey: locationSharingKey)
                locationSharingEnabled = false
                refreshViewState()
                showToast("설정 반영 실패, 다시 시도해주세요")
            }
        }
    }

    /// 익명 공유를 비활성화하고 핫스팟을 초기화합니다.
    func disableSharing() {
        guard let userId = currentUserId else {
            preferenceStore.set(false, forKey: locationSharingKey)
            locationSharingEnabled = false
            hotspots = []
            refreshViewState()
            return
        }

        isWorking = true
        let previous = locationSharingEnabled
        preferenceStore.set(false, forKey: locationSharingKey)
        locationSharingEnabled = false
        hotspots = []
        refreshViewState()
        showToast("익명 공유를 중지했어요")

        Task {
            defer { isWorking = false }
            do {
                try await nearbyService.setVisibility(userId: userId, enabled: false)
            } catch {
                preferenceStore.set(previous, forKey: locationSharingKey)
                locationSharingEnabled = previous
                refreshViewState()
                showToast("설정 반영 실패, 다시 시도해주세요")
            }
        }
    }

    /// 핫스팟을 새로 조회하고 카드 상태를 갱신합니다.
    func refreshHotspots(force: Bool = false) {
        guard screenState != .guestLocked else { return }
        guard permissionState == .authorized else {
            refreshViewState()
            return
        }
        guard locationSharingEnabled else {
            refreshViewState()
            return
        }
        guard let coordinate = locationManager.location?.coordinate else {
            screenState = hotspots.isEmpty ? .empty : .ready
            return
        }

        if force == false && Date().timeIntervalSince(lastRefreshAt) < 1.0 {
            return
        }

        isWorking = true
        if hotspots.isEmpty {
            screenState = .loading
        }
        let userId = currentUserId
        Task {
            defer { isWorking = false }
            do {
                let fetched = try await nearbyService.getHotspots(
                    userId: userId,
                    centerLatitude: coordinate.latitude,
                    centerLongitude: coordinate.longitude,
                    radiusKm: 1.0
                )
                hotspots = fetched
                lastRefreshAt = Date()
                updateHotspotSummary()
                if fetched.isEmpty {
                    screenState = .empty
                } else {
                    screenState = .ready
                }
            } catch {
                if isConnectivityError(error) {
                    screenState = hotspots.isEmpty ? .offlineEmpty : .offlineCached
                } else {
                    screenState = .errorRetryable
                }
            }
        }
    }

    /// 권한 안내 카드에서 시스템 설정 화면을 엽니다.
    func openSystemSettings() {
#if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
#endif
    }

    /// 짧은 사용자 피드백 메시지를 노출합니다.
    func showToast(_ message: String) {
        toastMessage = message
    }

    /// 노출 중인 토스트를 제거합니다.
    func clearToast() {
        toastMessage = nil
    }

    var sharingBadgeText: String {
        locationSharingEnabled ? "공유 중" : "비공개"
    }

    var sharingBadgeColor: Color {
        locationSharingEnabled ? Color.appGreen : Color.appTextLightGray
    }

    var permissionBadgeText: String {
        permissionState == .authorized ? "위치 허용" : "권한 필요"
    }

    var permissionBadgeColor: Color {
        permissionState == .authorized ? Color.appGreen : Color.appRed
    }

    private var currentUserId: String? {
        guard case .member(let userId) = sessionProvider() else { return nil }
        return userId
    }

    /// 권한 상태를 iOS 시스템 값에서 앱 상태로 변환합니다.
    private func updatePermissionState() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            permissionState = .authorized
        case .notDetermined:
            permissionState = .notDetermined
        case .denied, .restricted:
            permissionState = .denied
        @unknown default:
            permissionState = .denied
        }
    }

    /// 인증/권한/공유 상태를 바탕으로 라이벌 화면 상태를 결정합니다.
    private func refreshViewState() {
        guard currentUserId != nil else {
            screenState = .guestLocked
            return
        }
        guard permissionState == .authorized else {
            screenState = .permissionRequired
            return
        }
        guard locationSharingEnabled else {
            screenState = .consentRequired
            return
        }
        if hotspots.isEmpty {
            screenState = .empty
        } else {
            screenState = .ready
        }
    }

    /// 핫스팟 요약 텍스트를 계산해 카드에 표시합니다.
    private func updateHotspotSummary() {
        guard let maximum = hotspots.map(\.intensity).max() else {
            maxIntensityText = "없음"
            lastUpdatedText = "-"
            return
        }
        if maximum >= 0.67 {
            maxIntensityText = "높음"
        } else if maximum >= 0.34 {
            maxIntensityText = "보통"
        } else {
            maxIntensityText = "낮음"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        lastUpdatedText = formatter.string(from: Date())
    }

    /// 주기 조회 타이머를 시작해 공유 중 상태에서 10초마다 핫스팟을 갱신합니다.
    private func startPollingIfNeeded() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshHotspots(force: false)
            }
        }
    }

    /// 네트워크 계열 오류 여부를 판별합니다.
    private func isConnectivityError(_ error: Error) -> Bool {
        if error is URLError {
            return true
        }
        if let supabaseError = error as? SupabaseHTTPError {
            switch supabaseError {
            case .unexpectedStatusCode(let code):
                return code == 429 || (500...599).contains(code)
            default:
                return false
            }
        }
        return false
    }

    /// 위치 권한이 바뀌면 화면 상태를 즉시 재계산합니다.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updatePermissionState()
        refreshViewState()
        refreshHotspots(force: true)
    }

    /// 새 좌표를 받으면 공유 상태에서만 핫스팟을 즉시 갱신합니다.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard locations.isEmpty == false,
              locationSharingEnabled else { return }
        refreshHotspots(force: false)
    }
}
