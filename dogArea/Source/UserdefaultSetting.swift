//
//  UserdefaultSetting.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import Foundation
class UserdefaultSetting {
    enum keyValue: String {
        case userId = "userId"
        case userName = "userName"
        case userProfile = "userProfile"
        case petInfo = "petInfo"
        case selectedPetId = "selectedPetId"
        case createdAt = "createdAt"
        case nonce = "nonce"
    }
    static var shared = UserdefaultSetting()
    func savenonce(nonce: Double) {
        UserDefaults.standard.setValue(nonce, forKey: keyValue.nonce.rawValue)
    }
    func save(id: String, name: String, profile: String?, pet: [PetInfo], selectedPetId: UUID? = nil, createdAt: Double) {
        UserDefaults.standard.setValue(id, forKey: keyValue.userId.rawValue)
        UserDefaults.standard.setValue(name, forKey: keyValue.userName.rawValue)
        UserDefaults.standard.setValue(profile, forKey: keyValue.userProfile.rawValue)
        UserDefaults.standard.setStructArray(pet, forKey: keyValue.petInfo.rawValue)
        let activePetId = selectedPetId ?? pet.first?.id
        UserDefaults.standard.setValue(activePetId?.uuidString, forKey: keyValue.selectedPetId.rawValue)
        UserDefaults.standard.setValue(createdAt, forKey: keyValue.createdAt.rawValue)
    }
    func setSelectedPet(_ id: UUID?) {
        UserDefaults.standard.setValue(id?.uuidString, forKey: keyValue.selectedPetId.rawValue)
    }
    private func selectedPetId() -> UUID? {
        guard let value = UserDefaults.standard.string(forKey: keyValue.selectedPetId.rawValue) else {
            return nil
        }
        return UUID(uuidString: value)
    }
    func getValue() -> UserInfo? {
        guard let id = UserDefaults.standard.string(forKey: keyValue.userId.rawValue) ,
              let name = UserDefaults.standard.string(forKey: keyValue.userName.rawValue)
             
               else {return nil}
        let pets = UserDefaults.standard.structArrayData(PetInfo.self, forKey: keyValue.petInfo.rawValue)
        let createdAt = UserDefaults.standard.double(forKey: keyValue.createdAt.rawValue)
        let selectedPetId = self.selectedPetId() ?? pets.first?.id
        if let profile = UserDefaults.standard.string(forKey: keyValue.userProfile.rawValue){
            return .init(id: id, name: name, profile: profile, pet: pets, selectedPetId: selectedPetId, createdAt: createdAt)
        } else {
            return .init(id: id, name: name, profile: nil, pet: pets, selectedPetId: selectedPetId, createdAt: createdAt)
        }
    }
    #if DEBUG
    func removeAll() {
        UserDefaults.standard.removeObject(forKey: keyValue.userId.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.userName.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.userProfile.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.petInfo.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.selectedPetId.rawValue)
    }
    #endif
}
struct UserInfo: TimeCheckable {
    let id: String
    let name: String
    let profile: String?
    let pet: [PetInfo]
    var selectedPetId: UUID?
    var createdAt: TimeInterval
    var selectedPet: PetInfo? {
        guard !pet.isEmpty else { return nil }
        guard let selectedPetId = selectedPetId else { return pet.first }
        return pet.first(where: { $0.id == selectedPetId }) ?? pet.first
    }
}
struct PetInfo: Codable {
    let id: UUID
    let petName: String
    let petProfile: String?
    init(id: UUID = UUID(), petName: String, petProfile: String?) {
        self.id = id
        self.petName = petName
        self.petProfile = petProfile
    }
    enum CodingKeys: String, CodingKey {
        case id
        case petName
        case petProfile
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.petName = try container.decode(String.self, forKey: .petName)
        self.petProfile = try container.decodeIfPresent(String.self, forKey: .petProfile)
    }
}
extension UserDefaults {
    public func setStruct<T: Codable>(_ value: T?, forKey defaultName: String){
        let data = try? JSONEncoder().encode(value)
        set(data, forKey: defaultName)
    }
    
    public func structData<T>(_ type: T.Type, forKey defaultName: String) -> T? where T : Decodable {
        guard let encodedData = data(forKey: defaultName) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: encodedData)
    }
    
    public func setStructArray<T: Codable>(_ value: [T], forKey defaultName: String){
        let data = value.compactMap { try? JSONEncoder().encode($0) }
        set(data, forKey: defaultName)
    }
    
    public func structArrayData<T>(_ type: T.Type, forKey defaultName: String) -> [T] where T : Decodable {
        guard let encodedData = array(forKey: defaultName) as? [Data] else {
            return []
        }
        return encodedData.compactMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
