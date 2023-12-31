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
    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                TitleTextView(title: "로그인/회원가입", subTitle: "계정 정보가 필요해요!")
                Spacer()
                AppleSigninButton(userId: $userId)
            }
            .navigationDestination(item: $userId, destination: { info in
                ProfileSettingsView(path: $path,viewModel: .init(info: info))
            })
            .frame(maxHeight: .infinity)
            .background(Color.appColor(type: .appYellowPale, scheme: scheme))
        }
    }
}
struct AppleSigninButton : View{
    @Binding var userId: AppleUserInfo?
    @State var isLogined: Bool = false
    var body: some View{
        SignInWithAppleButton(
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: { result in
//                #if DEBUG
//                UserdefaultSetting().removeAll()
//                #endif
                switch result {
                case .success(let authResults):
//                    print("Apple Login Successful")
                    switch authResults.credential{
                    case let appleIDCredential as ASAuthorizationAppleIDCredential:
                        // 계정 정보 가져오기
                        var userInfo = UserdefaultSetting().getValue()
                        let UserIdentifier = appleIDCredential.user
                        let fullName = appleIDCredential.fullName
                        let name =  (fullName?.familyName ?? "") + (fullName?.givenName ?? "")
                        let IdentityToken = String(data: appleIDCredential.identityToken!, encoding: .utf8)
                        let AuthorizationCode = String(data: appleIDCredential.authorizationCode!, encoding: .utf8)
                        if userInfo?.name == UserIdentifier {
                            guard let info = userInfo else { return }
                            isLogined.toggle()
                            // 첫 가입 아님(이미 가입함)
                        } else {
                            let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                                      idToken: IdentityToken!,
                                                                      rawNonce: nil)
                            Auth.auth().signIn(with: credential){ result, error in
                                guard error == nil else {
                                    print(error?.localizedDescription)
                                    return
                                }
                                userId = .init(createdAt: Date().timeIntervalSince1970, id: appleIDCredential.user, name: name)
                            }
                        }

                    default:
                        break
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }
        )
        .frame(width : UIScreen.main.bounds.width * 0.9, height:50)
        .cornerRadius(5)
        .fullScreenCover(isPresented: $isLogined, content: {
            RootView()
        })

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
