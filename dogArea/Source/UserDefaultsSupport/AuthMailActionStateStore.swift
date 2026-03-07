import Foundation

final class AuthMailActionStateStore: AuthMailActionStateStoring {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let namespace: String

    /// 메일 resend snapshot을 UserDefaults에 저장하는 구현을 초기화합니다.
    /// - Parameters:
    ///   - defaults: snapshot persistence에 사용할 UserDefaults 저장소입니다.
    ///   - encoder: snapshot 인코딩에 사용할 JSON 인코더입니다.
    ///   - decoder: snapshot 디코딩에 사용할 JSON 디코더입니다.
    ///   - namespace: 액션별 저장 키 앞에 붙일 네임스페이스 접두사입니다.
    init(
        defaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        namespace: String = "auth.mail.resend.snapshot.v1"
    ) {
        self.defaults = defaults
        self.encoder = encoder
        self.decoder = decoder
        self.namespace = namespace
    }

    func snapshot(for key: AuthMailActionKey) -> AuthMailResendSnapshot? {
        guard let data = defaults.data(forKey: storageKey(for: key)) else {
            return nil
        }
        return try? decoder.decode(AuthMailResendSnapshot.self, from: data)
    }

    func save(_ snapshot: AuthMailResendSnapshot, for key: AuthMailActionKey) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey(for: key))
    }

    func removeSnapshot(for key: AuthMailActionKey) {
        defaults.removeObject(forKey: storageKey(for: key))
    }

    /// 네임스페이스와 액션 키를 결합해 저장소 키를 생성합니다.
    /// - Parameter key: 저장/조회/삭제에 사용할 메일 액션 고유 키입니다.
    /// - Returns: UserDefaults에 실제로 사용할 문자열 키입니다.
    private func storageKey(for key: AuthMailActionKey) -> String {
        "\(namespace).\(key.storageKey)"
    }
}
