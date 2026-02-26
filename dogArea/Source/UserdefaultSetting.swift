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
        case createdAt = "createdAt"
        case nonce = "nonce"
    }
    static var shared = UserdefaultSetting()
    func savenonce(nonce: Double) {
        UserDefaults.standard.setValue(nonce, forKey: keyValue.nonce.rawValue)
    }
    func save(id: String, name: String, profile: String?, pet: [PetInfo], createdAt: Double) {
        UserDefaults.standard.setValue(id, forKey: keyValue.userId.rawValue)
        UserDefaults.standard.setValue(name, forKey: keyValue.userName.rawValue)
        UserDefaults.standard.setValue(profile, forKey: keyValue.userProfile.rawValue)
        UserDefaults.standard.setStructArray(pet, forKey: keyValue.petInfo.rawValue)
        UserDefaults.standard.setValue(createdAt, forKey: keyValue.createdAt.rawValue)
    }
    func getValue() -> UserInfo? {
        guard let id = UserDefaults.standard.string(forKey: keyValue.userId.rawValue) ,
              let name = UserDefaults.standard.string(forKey: keyValue.userName.rawValue)
             
               else {return nil}
        let pets = UserDefaults.standard.structArrayData(PetInfo.self, forKey: keyValue.petInfo.rawValue)
        let createdAt = UserDefaults.standard.double(forKey: keyValue.createdAt.rawValue)
        if let profile = UserDefaults.standard.string(forKey: keyValue.userProfile.rawValue){
            return .init(id: id, name: name, profile: profile, pet: pets, createdAt: createdAt)
        } else {
            return .init(id: id, name: name, profile: nil, pet: pets, createdAt: createdAt)
        }
    }
    #if DEBUG
    func removeAll() {
        UserDefaults.standard.removeObject(forKey: keyValue.userId.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.userName.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.userProfile.rawValue)
        UserDefaults.standard.removeObject(forKey: keyValue.petInfo.rawValue)
    }
    #endif
}
struct UserInfo: TimeCheckable {
    let id: String
    let name: String
    let profile: String?
    let pet: [PetInfo]
    var createdAt: TimeInterval
}

enum CaricatureStatus: String, Codable {
    case queued
    case processing
    case ready
    case failed
}

struct PetInfo: Codable {
    var petName: String
    var petProfile: String?
    var caricatureURL: String? = nil
    var caricatureStatus: CaricatureStatus? = nil
    var caricatureProvider: String? = nil
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
        
        return try! JSONDecoder().decode(type, from: encodedData)
    }
    
    public func setStructArray<T: Codable>(_ value: [T], forKey defaultName: String){
        let data = value.map { try? JSONEncoder().encode($0) }
        
        set(data, forKey: defaultName)
    }
    
    public func structArrayData<T>(_ type: T.Type, forKey defaultName: String) -> [T] where T : Decodable {
        guard let encodedData = array(forKey: defaultName) as? [Data] else {
            return []
        }
        return encodedData.map { try! JSONDecoder().decode(type, from: $0) }
    }
}

extension UserdefaultSetting {
    func updateFirstPetCaricature(
        status: CaricatureStatus,
        caricatureURL: String? = nil,
        provider: String? = nil
    ) {
        guard let current = getValue(), current.pet.isEmpty == false else { return }
        var pets = current.pet
        pets[0].caricatureStatus = status
        if let caricatureURL {
            pets[0].caricatureURL = caricatureURL
            // Display generated profile first after it is ready.
            pets[0].petProfile = caricatureURL
        }
        if let provider {
            pets[0].caricatureProvider = provider
        }
        save(
            id: current.id,
            name: current.name,
            profile: current.profile,
            pet: pets,
            createdAt: current.createdAt
        )
    }
}
