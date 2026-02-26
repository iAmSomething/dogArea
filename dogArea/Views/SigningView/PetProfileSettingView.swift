//
//  PetProfileSettingView.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import SwiftUI

struct PetProfileSettingView: View {
    @Environment(\.colorScheme) var scheme
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authFlow: AuthFlowCoordinator
    @EnvironmentObject var viewModel: SigningViewModel
    @Binding var path: NavigationPath
    @State var imageSelect: Bool = false
    @State private var didCompleteSignup: Bool = false
    @State private var recoveryIssue: RecoveryIssue? = nil
    let onSignupCompleted: () -> Void

    init(path: Binding<NavigationPath>, onSignupCompleted: @escaping () -> Void = {}) {
        self._path = path
        self.onSignupCompleted = onSignupCompleted
    }

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
                        .stroke(!viewModel.petProfile.isNil ? Color.appColor(type: .appGreen, scheme: scheme) : Color.appColor(type: .appRed, scheme: scheme), lineWidth: 0.8)
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
                            .stroke(viewModel.petName != "" ? Color.appColor(type: .appGreen, scheme: scheme) : Color.appColor(type: .appRed, scheme: scheme), lineWidth: 0.8)
                    )
                    .padding(.horizontal)
            }
            UnderLine()
            TitleTextView(title: "강아지 상세 정보", type: .MediumTitle, subTitle: "품종/나이/성별을 입력하면 통계가 더 정확해져요! (선택)")
            HStack {
                TextField("품종 (예: 비숑)", text: $viewModel.petBreed)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.appColor(type: .appTextDarkGray, scheme: scheme), lineWidth: 0.8)
                    )
                    .padding(.horizontal)
            }
            HStack {
                TextField("나이 (숫자)", text: $viewModel.petAgeYearsText)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.appColor(type: .appTextDarkGray, scheme: scheme), lineWidth: 0.8)
                    )
                    .padding(.horizontal)
            }
            Picker("성별", selection: $viewModel.petGender) {
                ForEach(PetGender.allCases, id: \.rawValue) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            Spacer()
            Button(action: {
                viewModel.setValue()
            }, label: {
                Text("회원 가입하기")
            })
            .disabled(viewModel.petName.isEmpty)
                .padding()
                .background(viewModel.petName.isEmpty ? Color.appColor(type: .appTextDarkGray, scheme: scheme) :Color.appColor(type: .appGreen, scheme: scheme))
                .myCornerRadius(radius: 15)
        }.fullScreenCover(isPresented: $imageSelect, content: {
            ImagePicker(image: $viewModel.petProfile, type: .photoLibrary)
        }).overlay(content: {
            if viewModel.loading == .loading {
                LoadingView()
            }
        })
        .overlay(alignment: .top) {
            if let issue = recoveryIssue, viewModel.loading != .loading {
                RecoveryActionBanner(
                    issue: issue,
                    onPrimary: { handleRecoveryPrimaryAction(issue) },
                    onDismiss: { recoveryIssue = nil }
                )
                .padding(.top, 12)
            }
        }
        .onChange(of: viewModel.loading) { state in
            guard didCompleteSignup == false else { return }
            if state == .success {
                recoveryIssue = nil
                didCompleteSignup = true
                onSignupCompleted()
            } else if case let .fail(msg) = state {
                recoveryIssue = RecoveryIssueClassifier.fromErrorMessage(msg)
            }
        }
    }

    private func handleRecoveryPrimaryAction(_ issue: RecoveryIssue) {
        switch issue.kind {
        case .locationPermissionDenied:
            RecoverySystemAction.openAppSettings()
        case .networkOffline:
            viewModel.setValue()
        case .authExpired:
            authFlow.startReauthenticationFlow()
        }
    }
}
