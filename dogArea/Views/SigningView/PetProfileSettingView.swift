//
//  PetProfileSettingView.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import SwiftUI

struct PetProfileSettingView: View {
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
        ScrollView {
            VStack(spacing: 14) {
                TitleTextView(title: "강아지 사진",type: .MediumTitle, subTitle: "강아지 사진을 추가해주세요!")
                Button {
                    imageSelect.toggle()
                } label: {
                    Image(uiImage: viewModel.petProfile ?? .emptyImg)
                        .resizable()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .aspectRatio(contentMode: .fit)
                        .myCornerRadius(radius: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(viewModel.petProfile == nil ? Color.appTextLightGray : Color.appGreen, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    TitleTextView(title: "강아지 이름", type: .MediumTitle, subTitle: "강아지 이름을 입력해주세요!")
                    TextField("강아지 이름을 입력해주세요", text: $viewModel.petName)
                        .appInputField(validity: viewModel.petName.isEmpty == false)

                    TitleTextView(title: "강아지 상세 정보", type: .MediumTitle, subTitle: "견종/믹스/나이/성별 입력은 선택이며, 미입력도 정상 사용 가능해요")
                    TextField("견종/믹스/기타 (선택)", text: $viewModel.petBreed)
                        .appInputField()
                    TextField("나이 (숫자)", text: $viewModel.petAgeYearsText)
                        .keyboardType(.numberPad)
                        .appInputField()
                    Picker("성별", selection: $viewModel.petGender) {
                        ForEach(PetGender.allCases, id: \.rawValue) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button(action: {
                        viewModel.setValue()
                    }, label: {
                        Text("회원 가입하기")
                    })
                    .disabled(viewModel.petName.isEmpty)
                    .buttonStyle(AppFilledButtonStyle(role: viewModel.petName.isEmpty ? .neutral : .primary))
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
        .onChange(of: viewModel.loading) { _, state in
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
