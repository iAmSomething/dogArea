import Foundation

/// Supabase 인증을 통해 확정된 사용자 식별 정보입니다.
struct AuthenticatedUserIdentity: Equatable {
    let userId: String
    let email: String?
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
    /// 로컬에 저장된 사용자 식별 정보를 조회합니다.
    func currentIdentity() -> AuthenticatedUserIdentity?
    /// 로컬 인증 식별 정보를 제거합니다.
    func clear()
}

final class DefaultAuthSessionStore: AuthSessionStoreProtocol {
    static let shared = DefaultAuthSessionStore()

    private enum Key {
        static let userId = "auth.session.user_id.v1"
        static let email = "auth.session.email.v1"
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

    /// 로컬 인증 식별 정보를 제거합니다.
    func clear() {
        defaults.removeObject(forKey: Key.userId)
        defaults.removeObject(forKey: Key.email)
    }
}

protocol AuthRepositoryProtocol {
    /// 입력된 인증 요청을 실제 인증 서비스로 위임하고 식별 정보를 반환합니다.
    func authenticate(_ request: AuthRequest) async throws -> (identity: AuthenticatedUserIdentity, displayNameHint: String?)
}

final class DefaultAuthRepository: AuthRepositoryProtocol {
    private let credentialService: AppleCredentialAuthServiceProtocol

    init(credentialService: AppleCredentialAuthServiceProtocol = DeviceAppleCredentialAuthService.shared) {
        self.credentialService = credentialService
    }

    /// 입력된 인증 요청을 실제 인증 서비스로 위임하고 식별 정보를 반환합니다.
    func authenticate(_ request: AuthRequest) async throws -> (identity: AuthenticatedUserIdentity, displayNameHint: String?) {
        switch request {
        case let .apple(identityToken, appleUserId, nameHint):
            try await credentialService.signInWithApple(identityToken: identityToken)
            return (
                AuthenticatedUserIdentity(userId: appleUserId, email: nil),
                nameHint?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
        case let .emailSignIn(email, password):
            let identity = try await credentialService.signInWithEmail(email: email, password: password)
            return (identity, email.emailNameHint)
        case let .emailSignUp(email, password):
            let identity = try await credentialService.signUpWithEmail(email: email, password: password)
            return (identity, email.emailNameHint)
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
        sessionStore.persist(result.identity)

        let localProfileId = profileRepository.fetchUserInfo()?.id
        let requiresOnboarding = localProfileId != result.identity.userId
        return AuthUseCaseOutcome(
            identity: result.identity,
            displayNameHint: result.displayNameHint,
            requiresOnboarding: requiresOnboarding
        )
    }
}

protocol AppleCredentialAuthServiceProtocol {
    /// Apple identity token 기반 로그인 검증을 수행합니다.
    func signInWithApple(identityToken: String) async throws
    /// 이메일/비밀번호로 로그인하고 사용자 식별 정보를 반환합니다.
    func signInWithEmail(email: String, password: String) async throws -> AuthenticatedUserIdentity
    /// 이메일/비밀번호로 회원가입을 수행하고 사용자 식별 정보를 반환합니다.
    func signUpWithEmail(email: String, password: String) async throws -> AuthenticatedUserIdentity
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
