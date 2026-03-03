import Foundation

/// Supabase 인증을 통해 확정된 사용자 식별 정보입니다.
struct AuthenticatedUserIdentity: Equatable {
    let userId: String
    let email: String?
}

/// Supabase 토큰 세션(Access/Refresh)의 로컬 보관 모델입니다.
struct AuthTokenSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: TimeInterval
    let tokenType: String

    /// 현재 시각과 유효시간 버퍼를 기준으로 토큰 사용 가능 여부를 반환합니다.
    /// - Parameters:
    ///   - now: 비교 기준 epoch seconds입니다.
    ///   - leeway: 만료 직전 경계 오차를 흡수하기 위한 버퍼(초)입니다.
    /// - Returns: 현재 토큰을 바로 사용해도 되는지 여부입니다.
    func isValid(at now: TimeInterval, leeway: TimeInterval = 30) -> Bool {
        guard accessToken.isEmpty == false else { return false }
        return expiresAt - leeway > now
    }
}

/// 인증 요청 처리 결과(식별자 + 세션 토큰)를 나타냅니다.
struct AuthCredentialResult: Equatable {
    let identity: AuthenticatedUserIdentity
    let tokenSession: AuthTokenSession?
}

/// 로그인 입력의 채널/의도를 표현합니다.
enum AuthRequest: Equatable {
    case apple(identityToken: String, appleUserId: String, nameHint: String?)
    case emailSignIn(email: String, password: String)
    case emailSignUp(email: String, password: String)
}

/// 인증 수행 후 화면 전환 결정을 담는 결과입니다.
struct AuthUseCaseOutcome: Equatable {
    let identity: AuthenticatedUserIdentity
    let displayNameHint: String?
    let requiresOnboarding: Bool
}

protocol AuthSessionStoreProtocol {
    /// 현재 인증된 사용자 식별 정보를 로컬에 저장합니다.
    func persist(_ identity: AuthenticatedUserIdentity)
    /// 현재 인증된 토큰 세션을 로컬에 저장합니다.
    /// - Parameter tokenSession: Access/Refresh token과 만료 정보를 담은 세션입니다.
    func persist(tokenSession: AuthTokenSession)
    /// 로컬에 저장된 사용자 식별 정보를 조회합니다.
    /// - Returns: 사용자 식별 정보가 존재하면 해당 값을 반환하고, 없으면 `nil`을 반환합니다.
    func currentIdentity() -> AuthenticatedUserIdentity?
    /// 로컬에 저장된 토큰 세션 정보를 조회합니다.
    /// - Returns: 토큰 세션이 존재하면 해당 값을 반환하고, 없으면 `nil`을 반환합니다.
    func currentTokenSession() -> AuthTokenSession?
    /// 토큰 세션 정보만 제거합니다.
    func clearTokenSession()
    /// 로컬 인증 식별 정보를 제거합니다.
    func clear()
}

final class DefaultAuthSessionStore: AuthSessionStoreProtocol {
    static let shared = DefaultAuthSessionStore()

    private enum Key {
        static let userId = "auth.session.user_id.v1"
        static let email = "auth.session.email.v1"
        static let accessToken = "auth.session.access_token.v1"
        static let refreshToken = "auth.session.refresh_token.v1"
        static let expiresAt = "auth.session.expires_at.v1"
        static let tokenType = "auth.session.token_type.v1"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 현재 인증된 사용자 식별 정보를 로컬에 저장합니다.
    func persist(_ identity: AuthenticatedUserIdentity) {
        defaults.set(identity.userId, forKey: Key.userId)
        defaults.set(identity.email, forKey: Key.email)
    }

    /// 현재 인증된 토큰 세션을 로컬에 저장합니다.
    /// - Parameter tokenSession: Access/Refresh token과 만료 정보를 담은 세션입니다.
    func persist(tokenSession: AuthTokenSession) {
        defaults.set(tokenSession.accessToken, forKey: Key.accessToken)
        defaults.set(tokenSession.refreshToken, forKey: Key.refreshToken)
        defaults.set(tokenSession.expiresAt, forKey: Key.expiresAt)
        defaults.set(tokenSession.tokenType, forKey: Key.tokenType)
    }

    /// 로컬에 저장된 사용자 식별 정보를 조회합니다.
    func currentIdentity() -> AuthenticatedUserIdentity? {
        guard let userId = defaults.string(forKey: Key.userId), userId.isEmpty == false else {
            return nil
        }
        return AuthenticatedUserIdentity(
            userId: userId,
            email: defaults.string(forKey: Key.email)
        )
    }

    /// 로컬에 저장된 토큰 세션 정보를 조회합니다.
    /// - Returns: 토큰 세션이 존재하면 해당 값을 반환하고, 없으면 `nil`을 반환합니다.
    func currentTokenSession() -> AuthTokenSession? {
        guard
            let accessToken = defaults.string(forKey: Key.accessToken),
            let refreshToken = defaults.string(forKey: Key.refreshToken),
            let tokenType = defaults.string(forKey: Key.tokenType),
            accessToken.isEmpty == false,
            refreshToken.isEmpty == false,
            tokenType.isEmpty == false
        else {
            return nil
        }
        let expiresAt = defaults.double(forKey: Key.expiresAt)
        guard expiresAt > 0 else { return nil }
        return AuthTokenSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            tokenType: tokenType
        )
    }

    /// 토큰 세션 정보만 제거합니다.
    func clearTokenSession() {
        defaults.removeObject(forKey: Key.accessToken)
        defaults.removeObject(forKey: Key.refreshToken)
        defaults.removeObject(forKey: Key.expiresAt)
        defaults.removeObject(forKey: Key.tokenType)
    }

    /// 로컬 인증 식별 정보를 제거합니다.
    func clear() {
        defaults.removeObject(forKey: Key.userId)
        defaults.removeObject(forKey: Key.email)
        clearTokenSession()
    }
}

protocol AuthRepositoryProtocol {
    /// 입력된 인증 요청을 실제 인증 서비스로 위임하고 식별 정보를 반환합니다.
    /// - Parameter request: 인증 채널/의도를 포함한 인증 요청입니다.
    /// - Returns: 인증에 성공한 사용자 식별 정보와 선택적 세션 토큰입니다.
    func authenticate(_ request: AuthRequest) async throws -> (credential: AuthCredentialResult, displayNameHint: String?)
}

final class DefaultAuthRepository: AuthRepositoryProtocol {
    private let credentialService: AppleCredentialAuthServiceProtocol

    init(credentialService: AppleCredentialAuthServiceProtocol = DeviceAppleCredentialAuthService.shared) {
        self.credentialService = credentialService
    }

    /// 입력된 인증 요청을 실제 인증 서비스로 위임하고 식별 정보를 반환합니다.
    /// - Parameter request: 인증 채널/의도를 포함한 인증 요청입니다.
    /// - Returns: 인증에 성공한 사용자 식별 정보와 선택적 세션 토큰입니다.
    func authenticate(_ request: AuthRequest) async throws -> (credential: AuthCredentialResult, displayNameHint: String?) {
        switch request {
        case let .apple(identityToken, appleUserId, nameHint):
            try await credentialService.signInWithApple(identityToken: identityToken)
            return (
                AuthCredentialResult(
                    identity: AuthenticatedUserIdentity(userId: appleUserId, email: nil),
                    tokenSession: nil
                ),
                nameHint?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
        case let .emailSignIn(email, password):
            let credential = try await credentialService.signInWithEmail(email: email, password: password)
            return (credential, email.emailNameHint)
        case let .emailSignUp(email, password):
            let credential = try await credentialService.signUpWithEmail(email: email, password: password)
            return (credential, email.emailNameHint)
        }
    }
}

protocol AuthUseCaseProtocol {
    /// 인증 요청을 처리하고 기존 사용자/온보딩 필요 여부를 판정합니다.
    func execute(_ request: AuthRequest) async throws -> AuthUseCaseOutcome
}

final class DefaultAuthUseCase: AuthUseCaseProtocol {
    private let authRepository: AuthRepositoryProtocol
    private let profileRepository: ProfileRepository
    private let sessionStore: AuthSessionStoreProtocol

    init(
        authRepository: AuthRepositoryProtocol = DefaultAuthRepository(),
        profileRepository: ProfileRepository = DefaultProfileRepository.shared,
        sessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared
    ) {
        self.authRepository = authRepository
        self.profileRepository = profileRepository
        self.sessionStore = sessionStore
    }

    /// 인증 요청을 처리하고 기존 사용자/온보딩 필요 여부를 판정합니다.
    func execute(_ request: AuthRequest) async throws -> AuthUseCaseOutcome {
        let result = try await authRepository.authenticate(request)
        sessionStore.persist(result.credential.identity)
        if let tokenSession = result.credential.tokenSession {
            sessionStore.persist(tokenSession: tokenSession)
        }

        let localProfileId = profileRepository.fetchUserInfo()?.id
        let requiresOnboarding = localProfileId != result.credential.identity.userId
        return AuthUseCaseOutcome(
            identity: result.credential.identity,
            displayNameHint: result.displayNameHint,
            requiresOnboarding: requiresOnboarding
        )
    }
}

protocol AppleCredentialAuthServiceProtocol {
    /// Apple identity token 기반 로그인 검증을 수행합니다.
    func signInWithApple(identityToken: String) async throws
    /// 이메일/비밀번호로 로그인하고 사용자 식별 정보 및 세션 토큰을 반환합니다.
    /// - Parameters:
    ///   - email: 로그인 이메일입니다.
    ///   - password: 로그인 비밀번호입니다.
    /// - Returns: 로그인 사용자 식별 정보 및 선택적 세션 토큰입니다.
    func signInWithEmail(email: String, password: String) async throws -> AuthCredentialResult
    /// 이메일/비밀번호로 회원가입을 수행하고 사용자 식별 정보 및 세션 토큰을 반환합니다.
    /// - Parameters:
    ///   - email: 회원가입 이메일입니다.
    ///   - password: 회원가입 비밀번호입니다.
    /// - Returns: 가입된 사용자 식별 정보 및 선택적 세션 토큰입니다.
    func signUpWithEmail(email: String, password: String) async throws -> AuthCredentialResult
}

protocol ProfileImageRepository {
    func uploadUserProfileImage(data: Data, ownerId: String) async throws -> String
    func uploadPetProfileImage(data: Data, ownerId: String) async throws -> String
}

protocol ProfileRepository {
    func fetchUserInfo() -> UserInfo?
    func selectedPet(from userInfo: UserInfo?) -> PetInfo?
    @discardableResult
    func save(
        id: String,
        name: String,
        profile: String?,
        profileMessage: String?,
        pet: [PetInfo],
        createdAt: Double,
        selectedPetId: String?
    ) -> UserInfo?
    func setSelectedPetId(_ petId: String, source: String)
}

private extension String {
    /// 이메일 앞부분을 사용자 이름 힌트로 변환합니다.
    var emailNameHint: String? {
        split(separator: "@").first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    /// 공백 제거 후 빈 문자열이면 `nil`로 변환합니다.
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

final class DefaultProfileRepository: ProfileRepository {
    static let shared = DefaultProfileRepository()

    private let profileStore: ProfileStoring
    private let petSelectionStore: PetSelectionStoring
    private let syncCoordinator: ProfileSyncCoordinator

    init(
        profileStore: ProfileStoring = ProfileStore.shared,
        petSelectionStore: PetSelectionStoring = PetSelectionStore.shared,
        syncCoordinator: ProfileSyncCoordinator = .shared
    ) {
        self.profileStore = profileStore
        self.petSelectionStore = petSelectionStore
        self.syncCoordinator = syncCoordinator
    }

    func fetchUserInfo() -> UserInfo? {
        profileStore.getValue()
    }

    func selectedPet(from userInfo: UserInfo?) -> PetInfo? {
        petSelectionStore.selectedPet(from: userInfo ?? profileStore.getValue())
    }

    @discardableResult
    func save(
        id: String,
        name: String,
        profile: String?,
        profileMessage: String?,
        pet: [PetInfo],
        createdAt: Double,
        selectedPetId: String?
    ) -> UserInfo? {
        profileStore.save(
            id: id,
            name: name,
            profile: profile,
            profileMessage: profileMessage,
            pet: pet,
            createdAt: createdAt,
            selectedPetId: selectedPetId
        )
        guard let snapshot = profileStore.getValue() else { return nil }
        syncCoordinator.enqueueSnapshot(userInfo: snapshot)
        syncCoordinator.flushIfNeeded(force: true)
        return snapshot
    }

    func setSelectedPetId(_ petId: String, source: String) {
        petSelectionStore.setSelectedPetId(petId, source: source)
    }
}
