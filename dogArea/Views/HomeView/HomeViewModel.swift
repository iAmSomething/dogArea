import Foundation
import Combine

final class HomeViewModel: ObservableObject {
    @Published var polygonList: [Polygon] = []
    @Published var totalArea: Double = 0.0
    @Published var totalTime: Double = 0.0
    @Published var krAreas: AreaMeterCollection = .init()
    @Published var myArea: AreaMeter = .init("", 0.0)
    @Published var myAreaList: [AreaMeterDTO] = []
    @Published var userInfo: UserInfo? = nil
    @Published var selectedPetId: String = ""
    @Published var selectedPet: PetInfo? = nil
    @Published var guestDataUpgradeReport: GuestDataUpgradeReport? = nil
    @Published var boundarySplitContribution: DayBoundarySplitContribution? = nil
    @Published var aggregationStatusMessage: String? = nil
    @Published var aggregationTimeZoneIdentifier: String = TimeZone.current.identifier
    @Published var indoorMissionBoard: IndoorMissionBoard = .empty
    @Published var indoorMissionStatusMessage: String? = nil
    @Published var weatherFeedbackRemainingCount: Int = 2
    @Published var weatherFeedbackResultMessage: String? = nil
    @Published var weatherMissionStatusSummary: WeatherMissionStatusSummary = .empty
    @Published var latestWeatherSnapshot: WeatherSnapshot? = nil
    @Published var weatherDetailPresentation: HomeWeatherSnapshotCardPresentation = .placeholder
    @Published var indoorMissionPresentation: HomeIndoorMissionBoardPresentation = .empty
    @Published var weatherShieldDailySummary: WeatherShieldDailySummary? = nil
    @Published var seasonCatchupBuffStatusMessage: String? = nil
    @Published var seasonCatchupBuffStatusWarning: Bool = false
    @Published var isShowingAllRecordsOverride: Bool = false
    @Published var areaReferenceSections: [AreaReferenceSection] = []
    @Published var areaReferenceSource: AreaReferenceSource = .fallback
    @Published var areaReferenceSourceLabel: String = "기본 비교 구역"
    @Published var areaReferenceLastUpdatedAt: Date? = nil
    @Published var featuredAreaCount: Int = 0
    @Published var questMotionEvent: QuestMotionEvent? = nil
    @Published var questCompletionPresentation: QuestCompletionPresentation? = nil
    @Published var questReminderEnabled: Bool
    @Published var questAlternativeActionSuggestion: String? = nil
    @Published var seasonMotionSummary: SeasonMotionSummary = .empty
    @Published var seasonMotionEvent: SeasonMotionEvent? = nil
    @Published var seasonResultPresentation: SeasonResultPresentation? = nil
    @Published var seasonResetTransitionToken: UUID? = nil
    @Published var seasonRemainingTimeText: String = "-"
    @Published var lastSeasonResultPresentation: SeasonResultPresentation? = nil
    @Published var areaMilestonePresentation: AreaMilestoneEvent? = nil

    var allPolygons: [Polygon] = []
    var cancellables: Set<AnyCancellable> = []
    var lastIndoorMissionExposureTrackKey: String = ""
    var lastIndoorMissionExtensionTrackKey: String = ""
    var lastIndoorMissionDifficultyTrackKey: String = ""
    let indoorMissionStore = IndoorMissionStore()
    let metricTracker = AppMetricTracker.shared
    let areaReferenceRepository: AreaReferenceRepository
    let walkRepository: WalkRepositoryProtocol
    let userSessionStore: UserSessionStoreProtocol
    let eventCenter: AppEventCenterProtocol
    let weeklyStatisticsService: HomeWeeklyStatisticsServicing
    let areaAggregationService: HomeAreaAggregationServicing
    let weatherMissionStatusBuilder: HomeWeatherMissionStatusBuilding
    let weatherSnapshotPresentationService: HomeWeatherSnapshotPresenting
    let indoorMissionPresentationService: HomeIndoorMissionPresenting
    let weatherSnapshotStore: WeatherSnapshotStoreProtocol
    let areaMilestoneDetector: AreaMilestoneDetecting
    let areaMilestoneNotificationScheduler: AreaMilestoneNotificationScheduling
    let seasonMotionStore = SeasonMotionStore()
    let questReminderScheduler: QuestReminderScheduling
    let questReminderPreferenceStore = QuestReminderPreferenceStore()
    var featuredGoalAreas: [AreaMeter] = []
    var areaMilestoneQueue: [AreaMilestoneEvent] = []
    var areaReferenceTask: Task<Void, Never>? = nil
    var hasSkippedInitialActiveSceneRefresh: Bool = false

    var pets: [PetInfo] {
        userInfo?.pet.filter(\.isActive) ?? []
    }

    var selectedPetNameWithYi: String {
        (selectedPet?.petName ?? "강아지").addYi()
    }

    var selectedPetName: String {
        selectedPet?.petName ?? "강아지"
    }

    var shouldShowSelectedPetEmptyState: Bool {
        guard isShowingAllRecordsOverride == false else { return false }
        guard let selectedPetId = selectedPet?.petId, selectedPetId.isEmpty == false else { return false }
        guard allPolygons.isEmpty == false else { return false }
        let taggedPolygons = allPolygons.filter { ($0.petId?.isEmpty == false) }
        guard taggedPolygons.isEmpty == false else { return false }
        let selectedCount = taggedPolygons.filter { $0.petId == selectedPetId }.count
        return selectedCount == 0
    }

    var nextGoalArea: AreaMeter? {
        areaAggregationService.nextReferenceArea(
            currentArea: myArea,
            areaCollection: krAreas,
            featuredGoalAreas: featuredGoalAreas
        )
    }

    var weatherFeedbackWeeklyLimit: Int {
        indoorMissionStore.weeklyFeedbackLimit
    }

    var canSubmitWeatherMismatchFeedback: Bool {
        indoorMissionBoard.riskLevel != .clear && weatherFeedbackRemainingCount > 0
    }

    var remainingAreaToGoal: Double {
        guard let nextGoalArea else { return 0 }
        return max(0, nextGoalArea.area - myArea.area)
    }

    var goalProgressRatio: Double {
        guard let nextGoalArea, nextGoalArea.area > 0 else { return 1.0 }
        return min(1.0, max(0.0, myArea.area / nextGoalArea.area))
    }

    init(
        areaReferenceRepository: AreaReferenceRepository = SupabaseAreaReferenceRepository.shared,
        walkRepository: WalkRepositoryProtocol = WalkRepositoryContainer.shared,
        userSessionStore: UserSessionStoreProtocol = DefaultUserSessionStore.shared,
        eventCenter: AppEventCenterProtocol = DefaultAppEventCenter.shared,
        weeklyStatisticsService: HomeWeeklyStatisticsServicing = HomeWeeklyStatisticsService(),
        areaAggregationService: HomeAreaAggregationServicing = HomeAreaAggregationService(),
        weatherMissionStatusBuilder: HomeWeatherMissionStatusBuilding = HomeWeatherMissionStatusBuilder(),
        weatherSnapshotPresentationService: HomeWeatherSnapshotPresenting = HomeWeatherSnapshotPresentationService(),
        indoorMissionPresentationService: HomeIndoorMissionPresenting = HomeIndoorMissionPresentationService(),
        weatherSnapshotStore: WeatherSnapshotStoreProtocol = WeatherSnapshotStore.shared,
        areaMilestoneDetector: AreaMilestoneDetecting = AreaMilestoneDetector(),
        areaMilestoneNotificationScheduler: AreaMilestoneNotificationScheduling = LocalAreaMilestoneNotificationScheduler()
    ) {
        self.areaReferenceRepository = areaReferenceRepository
        self.walkRepository = walkRepository
        self.userSessionStore = userSessionStore
        self.eventCenter = eventCenter
        self.weeklyStatisticsService = weeklyStatisticsService
        self.areaAggregationService = areaAggregationService
        self.weatherMissionStatusBuilder = weatherMissionStatusBuilder
        self.weatherSnapshotPresentationService = weatherSnapshotPresentationService
        self.indoorMissionPresentationService = indoorMissionPresentationService
        self.weatherSnapshotStore = weatherSnapshotStore
        self.areaMilestoneDetector = areaMilestoneDetector
        self.areaMilestoneNotificationScheduler = areaMilestoneNotificationScheduler
        self.questReminderScheduler = LocalQuestReminderScheduler()
        self.questReminderEnabled = false
        self.questReminderEnabled = questReminderPreferenceStore.isEnabled
        bindSelectedPetSync()
        bindTimeBoundaryNotifications()
        bindSeasonCatchupBuffStatusNotifications()
        bindQuestProgressNotifications()
        reloadUserInfo()
        reloadSeasonCatchupBuffStatus()
        performInitialRefresh()
        Task { [weak self] in
            await self?.syncQuestReminderOnLaunch()
        }
    }

    deinit {
        areaReferenceTask?.cancel()
    }
}
