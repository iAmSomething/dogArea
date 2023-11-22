//
//  SigningViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import Foundation
import SwiftUI
import FirebaseStorage

class SigningViewModel: ObservableObject {
    @Published var loading: LoadingPhase = .initial
    @Published var userName: String = ""
    @Published var petName: String = ""
    @Published var userProfile: UIImage? = nil {
        didSet {
            print("새 이미지 선택됨")
        }
    }
    @Published var petProfile: UIImage? = nil
    var appleInfo: AppleUserInfo
    private var userId:String = ""
    private var petURL: String? = nil
    private var profileURL: String? = nil
    private var createdAt: Double
    private var storage = Storage.storage().reference()
    private let userdefaluts = UserdefaultSetting()
    init(info: AppleUserInfo) {
        self.appleInfo = info
        self.userName = info.name ?? ""
        self.userId = info.id
        self.createdAt = info.createdAt
    }
    func setValue(){
        loading = .loading
        Task{ @MainActor in
            do {
                if let img = userProfile {
                    profileURL = try await uploadImage(img: img, isPet: false)
                }
                if let img = petProfile {
                    petURL = try await uploadImage(img: img, isPet: true)
                }
                userdefaluts.save(id: userId, name: userName, profile: profileURL, pet: [.init(petName: petName, petProfile: petURL)], createdAt: createdAt)
                loading = .success
            }
        }
    }
    private func uploadImage(img: UIImage, isPet: Bool) async throws -> String?{
        guard let data = img.jpegData(compressionQuality: 0.3) else { return nil}
        var finished: Bool = false
        var urlString: String? = nil
        do {
            try await self.storage.child("images/\(userName)/" + (isPet ? "petProfile.jpeg" : "userProfile.jpeg")).putDataAsync(data) { p in
                if p?.isFinished == true {
                    finished = true
                    return
                } else if p?.isCancelled == true{
                    self.loading = .fail(msg: "업로드 실패")
                }
            }
        }
        if finished {
            urlString = try await getURL(isPet: isPet)
        }
        guard let str = urlString else { return nil}
        return str
    }
    private func getURL(isPet: Bool) async throws -> String{
        try await self.storage.child("images/\(userName)/" + (isPet ? "petProfile.jpeg" : "userProfile.jpeg"))
            .downloadURL()
            .absoluteString
    }
}
