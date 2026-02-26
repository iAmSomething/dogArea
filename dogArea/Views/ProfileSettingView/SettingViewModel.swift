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
    enum ProfileEditValidationError: LocalizedError {
        case userNotFound
        case invalidAgeRange

        var errorDescription: String? {
            switch self {
            case .userNotFound:
                return "사용자 정보를 불러오지 못했습니다."
            case .invalidAgeRange:
                return "나이는 0~30 사이 숫자로 입력해주세요."
            }
        }
    }

    @Published var polygonList: [Polygon] = []
    @Published var userName: String? = nil
    @Published var petName: String? = nil
    @Published var userInfo: UserInfo? = nil
    @Published var selectedPetId: String = ""
    @Published var selectedPet: PetInfo? = nil
    private var petURL: String? = nil
    private var profileURL: String? = nil
    private var storage = Storage.storage().reference()
    private let profileRepository: ProfileRepository
    private var cancellables: Set<AnyCancellable> = []

    var pets: [PetInfo] {
        userInfo?.pet ?? []
    }

    init(profileRepository: ProfileRepository = DefaultProfileRepository.shared) {
        self.profileRepository = profileRepository
        bindSelectedPetSync()
        fetchModel()
        reloadUserInfo()
    }
    func fetchModel() {
        self.polygonList = self.fetchPolygons()
    }

    func reloadUserInfo() {
        self.userInfo = profileRepository.fetchUserInfo()
        self.selectedPet = profileRepository.selectedPet(from: userInfo)
        self.selectedPetId = selectedPet?.petId ?? ""
    }

    func selectPet(_ petId: String) {
        guard pets.contains(where: { $0.petId == petId }) else { return }
        profileRepository.setSelectedPetId(petId, source: "setting")
        reloadUserInfo()
    }

    func updateProfileDetails(
        profileMessage: String,
        breed: String,
        ageYearsText: String,
        gender: PetGender
    ) -> Result<Void, ProfileEditValidationError> {
        guard let current = profileRepository.fetchUserInfo() else {
            return .failure(.userNotFound)
        }

        let normalizedProfileMessage = normalizeOptionalText(profileMessage)
        let normalizedBreed = normalizeOptionalText(breed)
        let normalizedAgeYears: Int?

        let trimmedAge = ageYearsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAge.isEmpty {
            normalizedAgeYears = nil
        } else if let parsed = Int(trimmedAge), (0...30).contains(parsed) {
            normalizedAgeYears = parsed
        } else {
            return .failure(.invalidAgeRange)
        }

        var pets = current.pet
        let targetPetId = selectedPetId.isEmpty == false ? selectedPetId : pets.first?.petId
        if let targetPetId,
           let index = pets.firstIndex(where: { $0.petId == targetPetId }) {
            pets[index].breed = normalizedBreed
            pets[index].ageYears = normalizedAgeYears
            pets[index].gender = gender
        }

        _ = profileRepository.save(
            id: current.id,
            name: current.name,
            profile: current.profile,
            profileMessage: normalizedProfileMessage,
            pet: pets,
            createdAt: current.createdAt,
            selectedPetId: targetPetId
        )

        if let targetPetId {
            profileRepository.setSelectedPetId(targetPetId, source: "profile_edit_save")
        } else {
            NotificationCenter.default.post(name: UserdefaultSetting.selectedPetDidChangeNotification, object: nil)
        }
        reloadUserInfo()
        return .success(())
    }

    private func normalizeOptionalText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func bindSelectedPetSync() {
        NotificationCenter.default.publisher(for: UserdefaultSetting.selectedPetDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadUserInfo()
            }
            .store(in: &cancellables)
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
