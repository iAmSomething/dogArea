import Foundation

extension UserDefaults {
    /// Codable 단일 값을 JSON으로 직렬화해 UserDefaults에 저장합니다.
    /// - Parameters:
    ///   - value: 저장할 Codable 값입니다. `nil`이면 빈 값을 기록합니다.
    ///   - defaultName: 값을 저장할 UserDefaults 키입니다.
    public func setStruct<T: Codable>(_ value: T?, forKey defaultName: String){
        let data = try? JSONEncoder().encode(value)
        set(data, forKey: defaultName)
    }
    
    /// UserDefaults에 저장된 JSON 데이터를 Codable 단일 값으로 역직렬화합니다.
    /// - Parameters:
    ///   - type: 복원할 모델 타입입니다.
    ///   - defaultName: 값을 조회할 UserDefaults 키입니다.
    /// - Returns: 역직렬화에 성공한 모델 값입니다. 데이터가 없거나 복원에 실패하면 `nil`입니다.
    public func structData<T>(_ type: T.Type, forKey defaultName: String) -> T? where T : Decodable {
        guard let encodedData = data(forKey: defaultName) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: encodedData)
    }
    
    /// Codable 배열을 요소별 JSON 데이터 배열로 직렬화해 UserDefaults에 저장합니다.
    /// - Parameters:
    ///   - value: 저장할 Codable 배열입니다.
    ///   - defaultName: 값을 저장할 UserDefaults 키입니다.
    public func setStructArray<T: Codable>(_ value: [T], forKey defaultName: String){
        let data = value.compactMap { try? JSONEncoder().encode($0) }
        set(data, forKey: defaultName)
    }
    
    /// UserDefaults에 저장된 JSON 데이터 배열을 Codable 배열로 역직렬화합니다.
    /// - Parameters:
    ///   - type: 복원할 요소 타입입니다.
    ///   - defaultName: 값을 조회할 UserDefaults 키입니다.
    /// - Returns: 역직렬화된 모델 배열입니다. 데이터가 없거나 복원에 실패한 항목은 제외됩니다.
    public func structArrayData<T>(_ type: T.Type, forKey defaultName: String) -> [T] where T : Decodable {
        guard let encodedData = array(forKey: defaultName) as? [Data] else {
            return []
        }
        return encodedData.compactMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
