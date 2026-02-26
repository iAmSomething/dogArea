//
//  SignInView.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import Foundation
import AuthenticationServices
import SwiftUI
import FirebaseAuth
struct SignInView: View {
    @Environment(\.colorScheme) var scheme
    @State var userId: AppleUserInfo? = nil
    @State var path = NavigationPath()
    let allowDismiss: Bool
    let onAuthenticated: () -> Void
    let onDismiss: () -> Void

    init(
        allowDismiss: Bool = false,
        onAuthenticated: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self.allowDismiss = allowDismiss
        self.onAuthenticated = onAuthenticated
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                TitleTextView(title: "로그인/회원가입", subTitle: "계정 정보가 필요해요!")
                Spacer()
                AppleSigninButton(userId: $userId, onAuthenticated: onAuthenticated)
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
                            let userInfo = UserdefaultSetting().getValue()
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
                                let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                                          idToken: identityToken,
                                                                          rawNonce: nil)
                                Auth.auth().signIn(with: credential){ _, error in
                                    isAuthenticating = false
                                    guard error == nil else {
                                        print(error?.localizedDescription ?? "apple sign in failed")
                                        return
                                    }
                                    userId = .init(createdAt: Date().timeIntervalSince1970, id: appleIDCredential.user, name: name)
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
