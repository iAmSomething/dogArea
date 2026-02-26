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
                let petInfo = PetInfo(
                    petName: petName,
                    petProfile: petURL,
                    caricatureURL: nil,
                    caricatureStatus: petURL == nil ? nil : .queued,
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
                enqueueCaricatureJobIfPossible()
            } catch {
                loading = .fail(msg: error.localizedDescription)
            }
        }
    }

    private func enqueueCaricatureJobIfPossible() {
        guard let petImageURL = self.petURL else { return }

        Task(priority: .background) { [userId, petName, petImageURL] in
            let client = CaricatureEdgeClient()
            UserdefaultSetting.shared.updateFirstPetCaricature(status: .processing)
            do {
                let response = try await client.requestCaricature(
                    petId: UUID().uuidString,
                    sourceImageURL: petImageURL,
                    requestId: UUID().uuidString
                )
                UserdefaultSetting.shared.updateFirstPetCaricature(
                    status: .ready,
                    caricatureURL: response.caricatureURL,
                    provider: response.provider
                )
                print("caricature ready for user=\(userId), pet=\(petName), job=\(response.jobId)")
            } catch {
                UserdefaultSetting.shared.updateFirstPetCaricature(status: .failed)
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

private struct CaricatureEdgeClient {
    struct ResponseDTO: Decodable {
        let jobId: String
        let provider: String?
        let caricatureUrl: String?

        var caricatureURL: String? { caricatureUrl }
    }

    struct RequestDTO: Encodable {
        let petId: String
        let sourceImagePath: String?
        let sourceImageUrl: String?
        let style: String
        let providerHint: String
        let requestId: String
    }

    enum RequestError: Error {
        case notConfigured
        case invalidURL
        case requestFailed
    }

    func requestCaricature(
        petId: String,
        sourceImageURL: String,
        requestId: String
    ) async throws -> ResponseDTO {
        let env = ProcessInfo.processInfo.environment
        let supabaseURL = env["SUPABASE_URL"] ?? ""
        let anonKey = env["SUPABASE_ANON_KEY"] ?? ""
        guard supabaseURL.isEmpty == false, anonKey.isEmpty == false else {
            throw RequestError.notConfigured
        }
        guard let url = URL(string: "\(supabaseURL)/functions/v1/caricature") else {
            throw RequestError.invalidURL
        }

        let payload = RequestDTO(
            petId: petId,
            sourceImagePath: nil,
            sourceImageUrl: sourceImageURL,
            style: "cute_cartoon",
            providerHint: "auto",
            requestId: requestId
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode,
              (200..<300).contains(statusCode) else {
            throw RequestError.requestFailed
        }
        return try JSONDecoder().decode(ResponseDTO.self, from: data)
    }
}
