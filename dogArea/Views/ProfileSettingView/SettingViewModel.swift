import Foundation
import Combine

final class SettingViewModel: ObservableObject {
    enum ProfileEditValidationError: LocalizedError {
        case userNotFound
        case invalidAgeRange
        case invalidDisplayName
        case invalidPetName
        case selectedPetNotFound
        case imageEncodingFailed
        case cannotDeactivateLastActivePet

        var errorDescription: String? {
            switch self {
            case .userNotFound:
                return "사용자 정보를 불러오지 못했습니다. 다시 로그인한 뒤 시도해주세요."
            case .invalidAgeRange:
                return "나이는 0~30 사이 숫자로 입력해주세요."
            case .invalidDisplayName:
                return "사용자 이름은 비워둘 수 없습니다."
            case .invalidPetName:
                return "반려견 이름은 비워둘 수 없습니다."
            case .selectedPetNotFound:
                return "선택된 반려견 정보를 찾지 못했습니다."
            case .imageEncodingFailed:
                return "이미지 처리에 실패했습니다. 다른 사진으로 다시 시도해주세요."
            case .cannotDeactivateLastActivePet:
                return "활성 반려견은 최소 1마리 이상 유지되어야 합니다."
            }
        }
    }

    @Published var polygonList: [Polygon] = []
    @Published var userName: String? = nil
    @Published var petName: String? = nil
    @Published var userInfo: UserInfo? = nil
    @Published var selectedPetId: String = ""
    @Published var selectedPet: PetInfo? = nil
    @Published var seasonProfileSummary: SeasonProfileSummary? = nil
    @Published var isCaricatureGenerating: Bool = false
    @Published var isAccountDeletionInProgress: Bool = false

    let profileRepository: ProfileRepository
    let imageRepository: ProfileImageRepository
    let petManagementService: SettingsPetManaging
    let accountDeletionService: AccountDeletionServiceProtocol
    let authSessionStore: AuthSessionStoreProtocol
    let walkRepository: WalkRepositoryProtocol
    let seasonProfileSummaryService: SettingsSeasonProfileSummaryProviding
    let featureFlags = FeatureFlagStore.shared
    let metricTracker = AppMetricTracker.shared
    let caricatureClient = CaricatureEdgeClient()
    var cancellables: Set<AnyCancellable> = []
    var uiTestPetManagementUserInfoOverride: UserInfo? = nil

    var pets: [PetInfo] {
        userInfo?.pet ?? []
    }

    var activePets: [PetInfo] {
        pets.filter(\.isActive)
    }

    var inactivePets: [PetInfo] {
        pets.filter { $0.isActive == false }
    }

    var isUITestPetManagementStubEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITest.PetManagementStub")
    }

    /// 설정 화면 뷰모델 의존성을 구성하고 초기 상태를 로드합니다.
    /// - Parameters:
    ///   - profileRepository: 사용자/반려견 프로필 읽기·저장을 담당하는 저장소입니다.
    ///   - imageRepository: 프로필 이미지 업로드를 담당하는 저장소입니다.
    ///   - petManagementService: 반려견 추가/수정/활성화 관리를 담당하는 서비스입니다.
    ///   - accountDeletionService: 회원탈퇴 요청을 처리하는 서비스입니다.
    ///   - authSessionStore: 인증 세션/식별자 조회를 담당하는 저장소입니다.
    ///   - walkRepository: 다각형 영역 데이터를 읽는 저장소입니다.
    ///   - seasonProfileSummaryService: 시즌 진행 현황 요약을 계산하는 서비스입니다.
    init(
        profileRepository: ProfileRepository = DefaultProfileRepository.shared,
        imageRepository: ProfileImageRepository = SupabaseProfileImageRepository.shared,
        petManagementService: SettingsPetManaging = SettingsPetManagementService(),
        accountDeletionService: AccountDeletionServiceProtocol = SupabaseAccountDeletionService.shared,
        authSessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared,
        walkRepository: WalkRepositoryProtocol = WalkRepositoryContainer.shared,
        seasonProfileSummaryService: SettingsSeasonProfileSummaryProviding = SettingsSeasonProfileSummaryService()
    ) {
        self.profileRepository = profileRepository
        self.imageRepository = imageRepository
        self.petManagementService = petManagementService
        self.accountDeletionService = accountDeletionService
        self.authSessionStore = authSessionStore
        self.walkRepository = walkRepository
        self.seasonProfileSummaryService = seasonProfileSummaryService
        bindSelectedPetSync()
        bindAuthSessionSync()
        fetchModel()
        reloadUserInfo()
    }

    /// 설정 화면에서 사용할 산책 영역 데이터를 로드합니다.
    func fetchModel() {
        polygonList = walkRepository.fetchPolygons()
    }

    /// 현재 사용자/선택 반려견/시즌 요약 상태를 한 번에 다시 로드합니다.
    func reloadUserInfo() {
        userInfo = resolveDisplayedUserInfo()
        selectedPet = profileRepository.selectedPet(from: userInfo)
        selectedPetId = selectedPet?.petId ?? ""
        userName = userInfo?.name
        petName = selectedPet?.petName
        reloadSeasonProfileSummary()
    }
}
