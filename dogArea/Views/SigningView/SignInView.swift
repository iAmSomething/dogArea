//
//  SignInView.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import Foundation
import AuthenticationServices
import SwiftUI
struct SignInView: View {
    @Environment(\.colorScheme) var scheme
    @State var userId: AppleUserInfo? = nil
    @State var path = NavigationPath()
    let allowDismiss: Bool
    let onAuthenticated: () -> Void
    let onDismiss: () -> Void
    private let authService: AppleCredentialAuthServiceProtocol
    private let profileRepository: ProfileRepository

    init(
        allowDismiss: Bool = false,
        onAuthenticated: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {},
        authService: AppleCredentialAuthServiceProtocol = DeviceAppleCredentialAuthService.shared,
        profileRepository: ProfileRepository = DefaultProfileRepository.shared
    ) {
        self.allowDismiss = allowDismiss
        self.onAuthenticated = onAuthenticated
        self.onDismiss = onDismiss
        self.authService = authService
        self.profileRepository = profileRepository
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                TitleTextView(title: "로그인/회원가입", subTitle: "계정 정보가 필요해요!")
                Spacer()
                AppleSigninButton(
                    userId: $userId,
                    onAuthenticated: onAuthenticated,
                    authService: authService,
                    profileRepository: profileRepository
                )
            }
            .navigationDestination(item: $userId, destination: { info in
                ProfileSettingsView(
                    path: $path,
                    viewModel: .init(info: info),
                    onSignupCompleted: onAuthenticated
                )
            })
            .frame(maxHeight: .infinity)
            .background(Color.appColor(type: .appYellowPale, scheme: scheme))
            .toolbar {
                if allowDismiss {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("나중에") {
                            onDismiss()
                        }
                    }
                }
            }
        }
    }
}
struct AppleSigninButton : View{
    @Binding var userId: AppleUserInfo?
    let onAuthenticated: () -> Void
    let authService: AppleCredentialAuthServiceProtocol
    let profileRepository: ProfileRepository
    @State private var isAuthenticating: Bool = false

    var body: some View{
        VStack(spacing: 8) {
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authResults):
                        isAuthenticating = true
                        switch authResults.credential{
                        case let appleIDCredential as ASAuthorizationAppleIDCredential:
                            let userInfo = profileRepository.fetchUserInfo()
                            let userIdentifier = appleIDCredential.user
                            let fullName = appleIDCredential.fullName
                            let name =  (fullName?.familyName ?? "") + (fullName?.givenName ?? "")
                            if userInfo?.id == userIdentifier {
                                isAuthenticating = false
                                onAuthenticated()
                            } else {
                                guard let identityTokenData = appleIDCredential.identityToken,
                                      let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                                    isAuthenticating = false
                                    print("identity token missing")
                                    return
                                }
                                if appleIDCredential.authorizationCode == nil {
                                    print("authorization code missing")
                                }
                                Task {
                                    do {
                                        try await authService.signInWithApple(identityToken: identityToken)
                                        await MainActor.run {
                                            isAuthenticating = false
                                            userId = .init(
                                                createdAt: Date().timeIntervalSince1970,
                                                id: appleIDCredential.user,
                                                name: name
                                            )
                                        }
                                    } catch {
                                        await MainActor.run {
                                            isAuthenticating = false
                                            print(error.localizedDescription)
                                        }
                                    }
                                }
                            }
                            
                        default:
                            isAuthenticating = false
                            break
                        }
                    case .failure(let error):
                        isAuthenticating = false
                        print(error.localizedDescription)
                    }
                }
            )
            .frame(width : UIScreen.main.bounds.width * 0.9, height:50)
            .cornerRadius(5)

            if isAuthenticating {
                ProgressView("로그인 처리 중...")
                    .font(.appFont(for: .Regular, size: 12))
            }
        }

    }
}
#Preview{
    SignInView()
}
struct AppleUserInfo: Identifiable, Hashable, TimeCheckable {
    var createdAt: TimeInterval
    let id: String
    let name: String?
}
