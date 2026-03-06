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
                ProfileEditorImageSection(
                    title: "강아지 사진",
                    subtitle: "강아지 사진을 추가해주세요!",
                    remoteURL: nil,
                    selectedImage: $viewModel.petProfile,
                    resetButtonTitle: "선택 취소",
                    resetButtonEnabled: viewModel.petProfile != nil,
                    allowsCamera: false,
                    onReset: {
                        viewModel.petProfile = nil
                    },
                    onCameraUnavailable: { }
                )

                ProfileEditorPetFieldsCard(
                    title: "반려견 정보",
                    subtitle: "이름은 필수, 견종/나이/성별은 선택입니다.",
                    petName: $viewModel.petName,
                    breed: $viewModel.petBreed,
                    ageYearsText: $viewModel.petAgeYearsText,
                    gender: $viewModel.petGender,
                    requiresPetName: true
                )
                .padding(.horizontal, 16)

                Button(action: {
                    viewModel.setValue()
                }, label: {
                    Text("회원 가입하기")
                })
                .disabled(viewModel.petName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(
                    AppFilledButtonStyle(
                        role: viewModel.petName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .neutral : .primary
                    )
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .overlay(content: {
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
