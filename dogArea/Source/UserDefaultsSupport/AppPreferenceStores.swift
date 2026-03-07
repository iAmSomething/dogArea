import Foundation
import Combine

protocol MapPreferenceStoreProtocol {
    /// Boolean 값을 조회합니다.
    /// - Parameters:
    ///   - key: 조회할 UserDefaults 키입니다.
    ///   - defaultValue: 저장값이 없을 때 반환할 기본값입니다.
    /// - Returns: 저장된 값 또는 기본값입니다.
    func bool(forKey key: String, default defaultValue: Bool) -> Bool
    /// 정수 값을 조회합니다.
    /// - Parameters:
    ///   - key: 조회할 UserDefaults 키입니다.
    ///   - defaultValue: 저장값이 0 이하이거나 없을 때 반환할 기본값입니다.
    /// - Returns: 저장된 값 또는 기본값입니다.
    func integer(forKey key: String, default defaultValue: Int) -> Int
    /// 실수 값을 조회합니다.
    /// - Parameters:
    ///   - key: 조회할 UserDefaults 키입니다.
    ///   - defaultValue: 저장값이 0 이하이거나 없을 때 반환할 기본값입니다.
    /// - Returns: 저장된 값 또는 기본값입니다.
    func double(forKey key: String, default defaultValue: Double) -> Double
    /// 문자열 값을 조회합니다.
    /// - Parameter key: 조회할 UserDefaults 키입니다.
    /// - Returns: 저장된 문자열입니다. 값이 없으면 `nil`입니다.
    func string(forKey key: String) -> String?
    /// 데이터 값을 조회합니다.
    /// - Parameter key: 조회할 UserDefaults 키입니다.
    /// - Returns: 저장된 데이터입니다. 값이 없으면 `nil`입니다.
    func data(forKey key: String) -> Data?
    /// 문자열 배열 값을 조회합니다.
    /// - Parameter key: 조회할 UserDefaults 키입니다.
    /// - Returns: 저장된 문자열 배열입니다. 값이 없으면 빈 배열입니다.
    func stringArray(forKey key: String) -> [String]
    /// Boolean 값을 저장합니다.
    /// - Parameters:
    ///   - value: 저장할 Boolean 값입니다.
    ///   - key: 값을 저장할 UserDefaults 키입니다.
    func set(_ value: Bool, forKey key: String)
    /// 문자열 값을 저장하거나 제거합니다.
    /// - Parameters:
    ///   - value: 저장할 문자열 값입니다. `nil`이면 기존 값을 제거합니다.
    ///   - key: 값을 저장할 UserDefaults 키입니다.
    func set(_ value: String?, forKey key: String)
    /// 데이터 값을 저장하거나 제거합니다.
    /// - Parameters:
    ///   - value: 저장할 데이터입니다. `nil`이면 기존 값을 제거합니다.
    ///   - key: 값을 저장할 UserDefaults 키입니다.
    func set(_ value: Data?, forKey key: String)
    /// 문자열 배열 값을 저장합니다.
    /// - Parameters:
    ///   - value: 저장할 문자열 배열입니다.
    ///   - key: 값을 저장할 UserDefaults 키입니다.
    func set(_ value: [String], forKey key: String)
    /// 저장된 값을 제거합니다.
    /// - Parameter key: 제거할 UserDefaults 키입니다.
    func removeObject(forKey key: String)
}

final class DefaultMapPreferenceStore: MapPreferenceStoreProtocol {
    static let shared = DefaultMapPreferenceStore()
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Boolean 값을 조회합니다.
    /// - Parameters:
    ///   - key: 조회할 UserDefaults 키입니다.
    ///   - defaultValue: 저장값이 없을 때 반환할 기본값입니다.
    /// - Returns: 저장된 값 또는 기본값입니다.
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        guard let value = userDefaults.object(forKey: key) as? Bool else {
            return defaultValue
        }
        return value
    }

    /// 정수 값을 조회합니다.
    /// - Parameters:
    ///   - key: 조회할 UserDefaults 키입니다.
    ///   - defaultValue: 저장값이 0 이하이거나 없을 때 반환할 기본값입니다.
    /// - Returns: 저장된 값 또는 기본값입니다.
    func integer(forKey key: String, default defaultValue: Int) -> Int {
        let value = userDefaults.integer(forKey: key)
        return value > 0 ? value : defaultValue
    }

    /// 실수 값을 조회합니다.
    /// - Parameters:
    ///   - key: 조회할 UserDefaults 키입니다.
    ///   - defaultValue: 저장값이 0 이하이거나 없을 때 반환할 기본값입니다.
    /// - Returns: 저장된 값 또는 기본값입니다.
    func double(forKey key: String, default defaultValue: Double) -> Double {
        let value = userDefaults.double(forKey: key)
        return value > 0 ? value : defaultValue
    }

    /// 문자열 값을 조회합니다.
    /// - Parameter key: 조회할 UserDefaults 키입니다.
    /// - Returns: 저장된 문자열입니다. 값이 없으면 `nil`입니다.
    func string(forKey key: String) -> String? {
        userDefaults.string(forKey: key)
    }

    /// 데이터 값을 조회합니다.
    /// - Parameter key: 조회할 UserDefaults 키입니다.
    /// - Returns: 저장된 데이터입니다. 값이 없으면 `nil`입니다.
    func data(forKey key: String) -> Data? {
        userDefaults.data(forKey: key)
    }

    /// 문자열 배열 값을 조회합니다.
    /// - Parameter key: 조회할 UserDefaults 키입니다.
    /// - Returns: 저장된 문자열 배열입니다. 값이 없으면 빈 배열입니다.
    func stringArray(forKey key: String) -> [String] {
        userDefaults.stringArray(forKey: key) ?? []
    }

    /// Boolean 값을 저장합니다.
    /// - Parameters:
    ///   - value: 저장할 Boolean 값입니다.
    ///   - key: 값을 저장할 UserDefaults 키입니다.
    func set(_ value: Bool, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    /// 문자열 값을 저장하거나 제거합니다.
    /// - Parameters:
    ///   - value: 저장할 문자열 값입니다. `nil`이면 기존 값을 제거합니다.
    ///   - key: 값을 저장할 UserDefaults 키입니다.
    func set(_ value: String?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    /// 데이터 값을 저장하거나 제거합니다.
    /// - Parameters:
    ///   - value: 저장할 데이터입니다. `nil`이면 기존 값을 제거합니다.
    ///   - key: 값을 저장할 UserDefaults 키입니다.
    func set(_ value: Data?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    /// 문자열 배열 값을 저장합니다.
    /// - Parameters:
    ///   - value: 저장할 문자열 배열입니다.
    ///   - key: 값을 저장할 UserDefaults 키입니다.
    func set(_ value: [String], forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    /// 저장된 값을 제거합니다.
    /// - Parameter key: 제거할 UserDefaults 키입니다.
    func removeObject(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
}

protocol AppEventCenterProtocol {
    /// 알림 관찰자를 등록합니다.
    /// - Parameters:
    ///   - name: 구독할 알림 이름입니다.
    ///   - object: 특정 발신 객체 필터입니다.
    ///   - queue: 콜백을 전달할 OperationQueue입니다.
    ///   - block: 알림 수신 시 실행할 콜백입니다.
    /// - Returns: 등록 해제에 사용할 관찰자 토큰입니다.
    func addObserver(
        forName name: Notification.Name,
        object: AnyObject?,
        queue: OperationQueue?,
        using block: @escaping (Notification) -> Void
    ) -> NSObjectProtocol
    /// 등록된 알림 관찰자를 해제합니다.
    /// - Parameter observer: 해제할 관찰자 토큰입니다.
    func removeObserver(_ observer: NSObjectProtocol)
    /// 알림을 즉시 발행합니다.
    /// - Parameters:
    ///   - name: 발행할 알림 이름입니다.
    ///   - object: 발신 객체입니다.
    ///   - userInfo: 함께 전달할 부가 정보입니다.
    func post(name: Notification.Name, object: AnyObject?, userInfo: [AnyHashable: Any]?)
    /// 알림을 Combine 퍼블리셔로 노출합니다.
    /// - Parameters:
    ///   - name: 구독할 알림 이름입니다.
    ///   - object: 특정 발신 객체 필터입니다.
    /// - Returns: 알림 이벤트를 전달하는 퍼블리셔입니다.
    func publisher(for name: Notification.Name, object: AnyObject?) -> AnyPublisher<Notification, Never>
}

final class DefaultAppEventCenter: AppEventCenterProtocol {
    static let shared = DefaultAppEventCenter()
    private let center: NotificationCenter

    init(center: NotificationCenter = .default) {
        self.center = center
    }

    /// 알림 관찰자를 등록합니다.
    /// - Parameters:
    ///   - name: 구독할 알림 이름입니다.
    ///   - object: 특정 발신 객체 필터입니다.
    ///   - queue: 콜백을 전달할 OperationQueue입니다.
    ///   - block: 알림 수신 시 실행할 콜백입니다.
    /// - Returns: 등록 해제에 사용할 관찰자 토큰입니다.
    func addObserver(
        forName name: Notification.Name,
        object: AnyObject?,
        queue: OperationQueue?,
        using block: @escaping (Notification) -> Void
    ) -> NSObjectProtocol {
        center.addObserver(forName: name, object: object, queue: queue, using: block)
    }

    /// 등록된 알림 관찰자를 해제합니다.
    /// - Parameter observer: 해제할 관찰자 토큰입니다.
    func removeObserver(_ observer: NSObjectProtocol) {
        center.removeObserver(observer)
    }

    /// 알림을 즉시 발행합니다.
    /// - Parameters:
    ///   - name: 발행할 알림 이름입니다.
    ///   - object: 발신 객체입니다.
    ///   - userInfo: 함께 전달할 부가 정보입니다.
    func post(name: Notification.Name, object: AnyObject?, userInfo: [AnyHashable: Any]?) {
        center.post(name: name, object: object, userInfo: userInfo)
    }

    /// 알림을 Combine 퍼블리셔로 노출합니다.
    /// - Parameters:
    ///   - name: 구독할 알림 이름입니다.
    ///   - object: 특정 발신 객체 필터입니다.
    /// - Returns: 알림 이벤트를 전달하는 퍼블리셔입니다.
    func publisher(for name: Notification.Name, object: AnyObject? = nil) -> AnyPublisher<Notification, Never> {
        center.publisher(for: name, object: object).eraseToAnyPublisher()
    }
}
