//
//  SettingViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/13/23.
//

import Foundation
import Combine
import UIKit
import FirebaseStorage
final class SettingViewModel: ObservableObject, CoreDataProtocol {
    @Published var polygonList: [Polygon] = []
    @Published var userName: String? = nil
    @Published var petName: String? = nil
    @Published var userInfo: UserInfo? = nil
    @Published var selectedPetId: String = ""
    @Published var selectedPet: PetInfo? = nil
    private var petURL: String? = nil
    private var profileURL: String? = nil
    private var storage = Storage.storage().reference()

    var pets: [PetInfo] {
        userInfo?.pet ?? []
    }

    init() {
        fetchModel()
        reloadUserInfo()
    }
    func fetchModel() {
        self.polygonList = self.fetchPolygons()
    }

    func reloadUserInfo() {
        self.userInfo = UserdefaultSetting.shared.getValue()
        self.selectedPet = UserdefaultSetting.shared.selectedPet(from: userInfo)
        self.selectedPetId = selectedPet?.petId ?? ""
    }

    func selectPet(_ petId: String) {
        guard pets.contains(where: { $0.petId == petId }) else { return }
        UserdefaultSetting.shared.setSelectedPetId(petId)
        reloadUserInfo()
    }
    func uploadImg(img: UIImage, isPet:Bool = false){
        Task{ @MainActor in
            do {
                if isPet {
                    petURL = try await uploadImage(img: img, isPet: isPet)
                } else {
                    profileURL = try await uploadImage(img: img, isPet: isPet)
                }
            }
        }
    }

    private func uploadImage(img: UIImage, isPet: Bool) async throws -> String?{
        guard let data = img.pngData() else { return nil}
        var finished: Bool = false
        var urlString: String? = nil
        do { try await self.storage.child("images/" + (isPet ? "petProfile.png" : "userProfile.png")).putDataAsync(data) { p in
            if p?.isFinished == true {
//                print("업로드 성공?")
                finished = true
                return
            } else if p?.isCancelled == true{
//                print("업로드 실패")
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
        try await self.storage.child("images/" + (isPet ? "petProfile.png" : "userProfile.png"))
            .downloadURL()
            .absoluteString
    }
}
