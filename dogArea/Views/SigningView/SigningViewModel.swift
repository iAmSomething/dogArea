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
    @Published var userProfile: UIImage? = nil
    @Published var petProfile: UIImage? = nil
    var appleInfo: AppleUserInfo
    private var userId:String = ""
    private var petURL: String? = nil
    private var profileURL: String? = nil
    private var createdAt: Double
    private var storage = Storage.storage().reference()
    private let userdefaluts = UserdefaultSetting()
    private let featureFlags = FeatureFlagStore.shared
    private let metricTracker = AppMetricTracker.shared
    init(info: AppleUserInfo) {
        self.appleInfo = info
        self.userName = info.name ?? ""
        self.userId = info.id
        self.createdAt = info.createdAt
        Task {
            _ = await FeatureFlagStore.shared.refresh()
        }
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
                let caricatureEnabled = featureFlags.isEnabled(.caricatureAsyncV1)
                let petInfo = PetInfo(
                    petName: petName,
                    petProfile: petURL,
                    caricatureURL: nil,
                    caricatureStatus: (caricatureEnabled && petURL != nil) ? .queued : nil,
                    caricatureProvider: nil
                )
                userdefaluts.save(
                    id: userId,
                    name: userName,
                    profile: profileURL,
                    pet: [petInfo],
                    createdAt: createdAt
                )
                loading = .success
                if caricatureEnabled, let currentPetURL = petURL {
                    enqueueCaricatureJobIfPossible(
                        petId: petInfo.petId,
                        userId: userId,
                        petImageURL: currentPetURL
                    )
                }
            } catch {
                loading = .fail(msg: error.localizedDescription)
            }
        }
    }

    private func enqueueCaricatureJobIfPossible(
        petId: String,
        userId: String,
        petImageURL: String
    ) {
        Task(priority: .background) { [petName, petId, userId, petImageURL] in
            let client = CaricatureEdgeClient()
            UserdefaultSetting.shared.updateFirstPetCaricature(status: .processing)
            do {
                let response = try await client.requestCaricature(
                    petId: petId,
                    userId: userId,
                    sourceImageURL: petImageURL,
                    requestId: UUID().uuidString
                )
                UserdefaultSetting.shared.updateFirstPetCaricature(
                    status: .ready,
                    caricatureURL: response.caricatureURL,
                    provider: response.provider
                )
                self.metricTracker.track(
                    .caricatureSuccess,
                    userKey: userId,
                    featureKey: .caricatureAsyncV1,
                    payload: ["provider": response.provider ?? "unknown"]
                )
                print("caricature ready for user=\(userId), pet=\(petName), job=\(response.jobId)")
            } catch {
                UserdefaultSetting.shared.updateFirstPetCaricature(status: .failed)
                self.metricTracker.track(
                    .caricatureFailed,
                    userKey: userId,
                    featureKey: .caricatureAsyncV1,
                    payload: ["error": error.localizedDescription]
                )
                print("caricature failed for user=\(userId), pet=\(petName): \(error.localizedDescription)")
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
