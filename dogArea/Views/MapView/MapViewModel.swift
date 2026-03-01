//
//  MapViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation
import Combine
import WatchConnectivity
#if canImport(UIKit)
import UIKit
#endif
class MapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate, WCSessionDelegate {
    enum WalkEndReason: String {
        case manual = "manual"
        case autoInactive = "auto_inactive"
        case autoTimeout = "auto_timeout"
    }

    enum WalkPointRecordMode: String {
        case manual
        case auto

        var title: String {
            switch self {
            case .manual: return "포인트 수동 기록"
            case .auto: return "포인트 자동 기록"
            }
        }
    }

    private struct ActiveWalkPointSnapshot: Codable {
        let latitude: Double
        let longitude: Double
        let createdAt: TimeInterval
    }

    private struct ActiveWalkSessionSnapshot: Codable {
        let sessionId: String?
        let startedAt: TimeInterval
        let elapsedTime: TimeInterval
        let selectedPetId: String?
        let selectedPetName: String
        let currentWalkingPetName: String
        let pointRecordMode: String
        let lastMovementAt: TimeInterval?
        let points: [ActiveWalkPointSnapshot]
        let savedAt: TimeInterval
    }

    private enum MapOverlayLODTuning {
        static let overlayMaxCameraDistanceKey = "map.lod.overlay.maxCameraDistance"
        static let overlayClusterThresholdKey = "map.lod.overlay.clusterThreshold"
        static let overlayPolygonCountThresholdKey = "map.lod.overlay.polygonCountThreshold"
        static let singleClusterOverlayLimitKey = "map.lod.overlay.singleClusterLimit"
        static let clusterCellDistanceRatioKey = "map.lod.cluster.cellDistanceRatio"
        static let clusterCellMinMetersKey = "map.lod.cluster.cellMinMeters"
        static let clusterCellMaxMetersKey = "map.lod.cluster.cellMaxMeters"

        static let overlayMaxCameraDistanceDefault = 4_500.0
        static let overlayClusterThresholdDefault = 24
        static let overlayPolygonCountThresholdDefault = 900
        static let singleClusterOverlayLimitDefault = 160
        static let clusterCellDistanceRatioDefault = 0.08
        static let clusterCellMinMetersDefault = 80.0
        static let clusterCellMaxMetersDefault = 500.0
    }

    private let locationManager = CLLocationManager()
    private var timer: Timer? = nil
    @Published var time: TimeInterval = 0.0
    @Published var startTime = Date()
    @Published var location: CLLocation?
    @Published var polygon : Polygon = Polygon(walkingTime: 0.0, walkingArea: 0.0)
    @Published var polygonList: [Polygon] = []
    @Published var selectedPolygonList: [Polygon] = []
    @Published var isWalking: Bool = false{
        didSet {
            //산책 시작 버튼 눌렀을 때
            if self.isWalking {
                self.showOnlyOne = true
            }
            self.publishWatchState()
        }
    }
    @Published var centerLocations: [Cluster] = []
    @Published private(set) var currentCameraDistance: Double = 2_000
    @Published var camera: MapCamera = .init(.init())
    @Published var cameraPosition = MapCameraPosition.userLocation(followsHeading: false,fallback: .automatic)
    @Published var selectedMarker: Location? = nil
    @Published var showOnlyOne: Bool = true
    @Published var heatmapEnabled: Bool = true
    @Published var heatmapCells: [HeatmapCellDTO] = []
    @Published var nearbyHotspotEnabled: Bool = true
    @Published var locationSharingEnabled: Bool = false
    @Published var nearbyHotspots: [NearbyHotspotDTO] = []
    @Published var selectedPetId: String? = nil
    @Published var selectedPetName: String = "강아지"
    @Published var availablePets: [PetInfo] = []
    @Published var currentWalkingPetName: String = "강아지"
    @Published var walkStartCountdownEnabled: Bool = false
    @Published var walkPointRecordMode: WalkPointRecordMode = .manual
    @Published private(set) var walkAutoEndPolicyEnabled: Bool = true
    @Published var hasRecoverableWalkSession: Bool = false
    @Published var recoverableWalkSummaryText: String = ""
    @Published var recoverableWalkEstimateText: String = ""
    @Published var watchSyncStatusText: String = "워치 동기화 대기"
    @Published var latestWatchActionText: String = ""
    @Published var walkStatusMessage: String? = nil
    @Published var runtimeGuardStatusText: String = ""
    @Published var syncOutboxPendingCount: Int = 0
    @Published var syncOutboxPermanentFailureCount: Int = 0
    @Published var syncOutboxLastErrorCodeText: String = ""
    @Published var syncRecoveryToastMessage: String? = nil
    @Published private(set) var captureRipples: [CaptureRipple] = []
    @Published private(set) var clusterMotionTransition: ClusterMotionTransition = .none
    @Published private(set) var clusterMotionToken: Int = 0
    @Published private(set) var weatherOverlayRiskLevel: WeatherOverlayRiskLevel = .clear
    @Published private(set) var weatherOverlayOpacity: Double = 0.0
    @Published private(set) var weatherOverlayStatusText: String = "날씨 상태 정상"
    @Published private(set) var weatherOverlayFallbackActive: Bool = false
    @Published var mapMotionReduced: Bool = false
    private let watchSession = WCSession.isSupported() ? WCSession.default : nil
    private let featureFlags = FeatureFlagStore.shared
    private let metricTracker = AppMetricTracker.shared
    private let nearbyService = NearbyPresenceService()
    private var nearbyTickTimer: Timer? = nil
    private var lastPresenceSentAt: Date = .distantPast
    private var lastNearbyFetchedAt: Date = .distantPast
    private var processedWatchActionIds: Set<String> = []
    private var processedWatchActionOrder: [String] = []
    private let maxProcessedWatchActions = 500
    private var lastWatchContextSyncAt: Date = .distantPast
    private var lastAppliedWatchActionId: String = ""
    private let processedWatchActionStorageKey = "watch.processedActionIds"
    private let activeWalkSessionStorageKey = "walk.activeSession.v1"
    private let heatmapEnabledKey = "heatmap.enabled"
    private let locationSharingKey = "nearby.locationSharingEnabled"
    private let nearbyHotspotEnabledKey = "nearby.hotspotEnabled"
    private let nearbyPresenceUserIdKey = "nearby.presenceUserId"
    private let mapMotionReducedKey = "map.motion.reduced"
    private let weatherRiskOverrideKey = "weather.risk.level.v1"
    private var lastAutoRecordedLocation: CLLocation?
    private var lastAutoRecordedAt: Date = .distantPast
    private let autoRecordMinDistance: CLLocationDistance = 12.0
    private let autoRecordMinInterval: TimeInterval = 8.0
    private let autoRecordNoiseDistance: CLLocationDistance = 4.0
    private let locationAccuracyThreshold: CLLocationAccuracy = 65.0
    private let inactivityAccuracyThreshold: CLLocationAccuracy = 40.0
    private let inactivitySpeedThreshold: CLLocationSpeed = 0.3
    private let inactivityDistanceThreshold: CLLocationDistance = 25.0
    private let jumpSpeedThreshold: CLLocationSpeed = 12.0
    private let jumpDistanceThreshold: CLLocationDistance = 150.0
    private let jumpTimeWindow: TimeInterval = 10.0
    private let restCandidateInterval: TimeInterval = 300.0
    private let inactivityWarningInterval: TimeInterval = 720.0
    private let inactivityFinalizeInterval: TimeInterval = 900.0
    private let walkAutoTimeoutInterval: TimeInterval = 3600.0
    private let recoverableSessionMaxAge: TimeInterval = 43_200.0
    private var lastPointEventAt: Date?
    private var lastMovementAt: Date?
    private var movementAnchorLocation: CLLocation?
    private var didNotifyRestCandidate: Bool = false
    private var didNotifyInactivityWarning: Bool = false
    private var lastSnapshotPersistAt: Date = .distantPast
    private var pendingRecoverableSession: ActiveWalkSessionSnapshot?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var lastAcceptedWalkLocation: CLLocation?
    private var lastSyncFlushAt: Date = .distantPast
    private var lastSyncSummarySnapshot: SyncOutboxSummary? = nil
    private var syncFlushTask: Task<Void, Never>? = nil
    private let syncOutbox = SyncOutboxStore.shared
    private let syncTransport = SupabaseSyncOutboxTransport()
    private let walkRepository: WalkRepositoryProtocol
    private let userSessionStore: UserSessionStoreProtocol
    private let authSessionStore: AuthSessionStoreProtocol
    private let preferenceStore: MapPreferenceStoreProtocol
    private let eventCenter: AppEventCenterProtocol
    private var lastCaptureHapticAt: Date = .distantPast
    private var lastWarningHapticAt: Date = .distantPast
    private let maxCaptureRipples = 12
    private let trailLifetime: TimeInterval = 5.0
    private let trailLimit = 12

    private enum WatchIncomingAction: String {
        case startWalk
        case addPoint
        case endWalk
        case syncState
    }

    private struct WatchActionEnvelope {
        let version: String
        let action: WatchIncomingAction
        let actionId: String
        let sentAt: TimeInterval?
    }

    private enum WatchContract {
        static let version = "watch.remote.v1"
        static let actionType = "watch_action"
        static let ackType = "watch_ack"
    }

    private enum PointAppendSource {
        case manual
        case auto
        case watch
    }

    enum ClusterMotionTransition {
        case none
        case decompose
        case merge
    }

    enum WeatherOverlayRiskLevel: String {
        case clear
        case caution
        case bad
        case severe

        var displayTitle: String {
            switch self {
            case .clear: return "정상"
            case .caution: return "주의"
            case .bad: return "악천후"
            case .severe: return "고위험"
            }
        }
    }

    struct CaptureRipple: Identifiable {
        let id: UUID
        let coordinate: CLLocationCoordinate2D
        let createdAt: TimeInterval

        init(
            id: UUID = UUID(),
            coordinate: CLLocationCoordinate2D,
            createdAt: TimeInterval = Date().timeIntervalSince1970
        ) {
            self.id = id
            self.coordinate = coordinate
            self.createdAt = createdAt
        }
    }

    struct TrailMarker: Identifiable {
        let id: UUID
        let coordinate: CLLocationCoordinate2D
        let age: TimeInterval

        var opacity: Double {
            let ratio = min(1.0, max(0.0, age / 5.0))
            return 0.75 - (ratio * 0.65)
        }

        var scale: Double {
            let ratio = min(1.0, max(0.0, age / 5.0))
            return 0.95 + ((1.0 - ratio) * 0.25)
        }
    }

    init(
        walkRepository: WalkRepositoryProtocol = WalkRepositoryContainer.shared,
        userSessionStore: UserSessionStoreProtocol = DefaultUserSessionStore.shared,
        authSessionStore: AuthSessionStoreProtocol = DefaultAuthSessionStore.shared,
        preferenceStore: MapPreferenceStoreProtocol = DefaultMapPreferenceStore.shared,
        eventCenter: AppEventCenterProtocol = DefaultAppEventCenter.shared
    ) {
        self.walkRepository = walkRepository
        self.userSessionStore = userSessionStore
        self.authSessionStore = authSessionStore
        self.preferenceStore = preferenceStore
        self.eventCenter = eventCenter
        super.init()
        self.locationManager.delegate = self
        self.locationManager.allowsBackgroundLocationUpdates = true
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest // 정확도 설정
        self.locationManager.requestWhenInUseAuthorization() // 권한 요청
        self.locationManager.startUpdatingLocation() // 위치 업데이트 시작
        self.reloadPolygonState(restoreLatestPolygon: true)
        self.loadProcessedWatchActions()

        let storedHeatmapEnabled = preferenceStore.bool(forKey: heatmapEnabledKey, default: true)
        let storedNearbyHotspotEnabled = preferenceStore.bool(forKey: nearbyHotspotEnabledKey, default: true)
        let storedLocationSharingEnabled = preferenceStore.bool(forKey: locationSharingKey, default: false)
        let storedMotionReduced = preferenceStore.bool(forKey: mapMotionReducedKey, default: false)

        self.heatmapEnabled = featureFlags.isEnabled(.heatmapV1) ? storedHeatmapEnabled : false
        let nearbyFeatureOn = featureFlags.isEnabled(.nearbyHotspotV1)
        self.nearbyHotspotEnabled = nearbyFeatureOn ? storedNearbyHotspotEnabled : false
        self.locationSharingEnabled = nearbyFeatureOn ? storedLocationSharingEnabled : false
        self.mapMotionReduced = storedMotionReduced
        self.walkStartCountdownEnabled = userSessionStore.walkStartCountdownEnabled()
        self.walkAutoEndPolicyEnabled = true
        self.walkPointRecordMode = WalkPointRecordMode(
            rawValue: userSessionStore.walkPointRecordModeRawValue()
        ) ?? .manual
        self.prepareRecoverableSessionIfNeeded()
        self.reloadSelectedPetContext()
        self.setupWatchConnectivity()
        self.setupLifecycleObservers()
        self.startNearbyTicker()
        self.syncVisibilitySettingIfNeeded()
        self.refreshFeatureFlagsFromRemote()
        self.refreshSyncOutboxSummary()
        self.flushSyncOutboxIfNeeded(force: true)
        self.refreshWeatherOverlayRisk()
    }

    deinit {
        timer?.invalidate()
        nearbyTickTimer?.invalidate()
        syncFlushTask?.cancel()
        lifecycleObservers.forEach { eventCenter.removeObserver($0) }
    }

    private func applyPolygonList(_ polygons: [Polygon], restoreLatestPolygon: Bool = false) {
        self.polygonList = polygons
        if restoreLatestPolygon {
            self.polygon = polygons.last ?? Polygon(walkingTime: 0.0, walkingArea: 0.0)
        }
        self.refreshHeatmap()
    }

    private func reloadPolygonState(restoreLatestPolygon: Bool = false) {
        let latest = self.walkRepository.fetchPolygons()
        self.applyPolygonList(latest, restoreLatestPolygon: restoreLatestPolygon)
    }

    func fetchPolygonList() {
        self.reloadPolygonState()
    }
    func fetchSelectedPolygonList(for clusters: Cluster) {
        if clusters.sumLocs.count == self.selectedPolygonList.count {
            var isSame = true
            for i in selectedPolygonList.indices {
                isSame = isSame && clusters.sumLocs[i].1 == self.selectedPolygonList[i].id
            }
            if isSame {
                self.selectedPolygonList = []
                return }
        }
        self.selectedPolygonList = []
        for loc in clusters.sumLocs {
            if let p = self.polygonList.polygon(at: loc.1) {
                self.selectedPolygonList.append(p)
            }
        }
    }
    func addLocation(){
        guard let location = self.location else { return }
        appendWalkPoint(from: location, recordedAt: Date(), source: .manual)
    }
    func removeLocation(_ locationID : UUID){
        if polygon.locations.firstIndex(where:{ $0.id == locationID}) != nil {
            polygon.removeAt(locationID)
            if polygon.locations.count<3 {
                let updated = walkRepository.deletePolygon(id: self.polygon.id)
                self.applyPolygonList(updated)
            }
        }
    }
    func makePolygon() {
        if self.polygon.locations.count > 2{
            polygon.makePolygon(walkArea: calculateArea(), walkTime: self.time)
        }
    }
    func endWalk(
        img: UIImage? = nil,
        reason: WalkEndReason = .manual,
        endedAtOverride: Date? = nil
    ) {
        if isWalking {
                timerStop()
                if self.polygon.locations.count > 2{
                    if let endedAtOverride {
                        self.time = max(0, endedAtOverride.timeIntervalSince(self.startTime))
                    }
                    self.polygon.petId = selectedPetId
                    polygon.makePolygon(walkArea: calculateArea(), walkTime: self.time, img: img)
                    let completedPolygon = self.polygon
                    let updated = walkRepository.savePolygon(completedPolygon)
                    let saved = updated.contains(where: { $0.id == completedPolygon.id })
                    metricTracker.track(
                        saved ? .walkSaveSuccess : .walkSaveFailed,
                        userKey: currentMetricUserId(),
                        featureKey: .heatmapV1,
                        payload: ["pointCount": "\(completedPolygon.locations.count)"]
                    )
                    if saved {
                        let endedAt = (endedAtOverride ?? Date()).timeIntervalSince1970
                        WalkSessionMetadataStore.shared.set(
                            sessionId: completedPolygon.id,
                            reason: .init(rawValue: reason.rawValue) ?? .manual,
                            endedAt: endedAt,
                            petId: selectedPetId
                        )
                        enqueueSyncOutbox(for: completedPolygon, hasImage: img != nil)
                    } else {
                        walkStatusMessage = "로컬 저장에 실패해 동기화 큐 적재를 건너뛰었습니다."
                    }
                    self.applyPolygonList(updated)
                }
            time = 0.0
            self.currentWalkingPetName = self.selectedPetName
            self.resetAutoPointRecordState()
            self.resetInactivityTracking(now: Date(), clearAnchor: true)
            self.clearActiveWalkSession()
        }
        else {
            clearActiveWalkSession()
            self.reloadSelectedPetContext()
            setTrackingMode()
            startTime = Date()
            timerSet()
            polygon.clear()
            polygon.petId = selectedPetId
            self.currentWalkingPetName = self.selectedPetName
            self.resetAutoPointRecordState()
            self.lastAcceptedWalkLocation = nil
            self.lastPointEventAt = Date()
            self.resetInactivityTracking(now: Date(), clearAnchor: true)
            self.persistActiveWalkSession(force: true)
        }
        withAnimation{ [weak self] in
            self?.isWalking.toggle()
        }
        self.syncWatchContext(force: true)
    }

    func startWalkNow() {
        guard isWalking == false else { return }
        endWalk()
    }

    func discardCurrentWalk() {
        guard isWalking else { return }
        timerStop()
        polygon.clear()
        time = 0.0
        selectedPolygonList = []
        currentWalkingPetName = selectedPetName
        resetAutoPointRecordState()
        resetInactivityTracking(now: Date(), clearAnchor: true)
        lastAcceptedWalkLocation = nil
        clearActiveWalkSession()
        withAnimation { [weak self] in
            self?.isWalking = false
        }
        syncWatchContext(force: true)
    }

    func toggleWalkStartCountdown() {
        walkStartCountdownEnabled.toggle()
        userSessionStore.setWalkStartCountdownEnabled(walkStartCountdownEnabled)
    }

    func toggleWalkPointRecordMode() {
        walkPointRecordMode = walkPointRecordMode == .manual ? .auto : .manual
        userSessionStore.setWalkPointRecordModeRawValue(walkPointRecordMode.rawValue)
        resetAutoPointRecordState()
    }

    var isAutoPointRecordMode: Bool {
        walkPointRecordMode == .auto
    }

    var autoEndPolicySummaryText: String {
        "무이동 5/12/15분 단계(휴식 후보/경고/자동 종료) + 최대 1시간 자동 종료"
    }

    var autoEndPolicyHintText: String {
        "판정 기준: 정확도 40m 이내, 속도 0.3m/s 미만, 이동거리 25m 미만"
    }

    var shouldShowWatchStatus: Bool {
        isWalking || latestWatchActionText.isEmpty == false
    }

    var hasRuntimeGuardStatus: Bool {
        runtimeGuardStatusText.isEmpty == false
    }

    var hasSyncOutboxStatus: Bool {
        syncOutboxPendingCount > 0 || syncOutboxPermanentFailureCount > 0
    }

    var isLocationPermissionDenied: Bool {
        let status = locationManager.authorizationStatus
        return status == .restricted || status == .denied
    }

    var isOfflineRecoveryMode: Bool {
        syncOutboxPendingCount > 0 && syncOutboxLastErrorCodeText == SyncOutboxErrorCode.offline.rawValue
    }

    var syncOutboxStatusText: String {
        if syncOutboxPermanentFailureCount > 0 {
            if syncOutboxLastErrorCodeText.isEmpty == false {
                return "동기화 영구실패 \(syncOutboxPermanentFailureCount)건 (\(syncOutboxLastErrorCodeText))"
            }
            return "동기화 영구실패 \(syncOutboxPermanentFailureCount)건"
        }
        if syncOutboxPendingCount > 0 {
            return "동기화 대기 \(syncOutboxPendingCount)건"
        }
        return ""
    }

    func clearWalkStatusMessage() {
        walkStatusMessage = nil
    }

    func clearRuntimeGuardStatus() {
        runtimeGuardStatusText = ""
    }

    func clearSyncRecoveryToastMessage() {
        syncRecoveryToastMessage = nil
    }

    func retrySyncNow() {
        walkStatusMessage = "동기화를 다시 시도합니다."
        flushSyncOutboxIfNeeded(force: true)
    }

    private func refreshSyncOutboxSummary() {
        let previous = lastSyncSummarySnapshot
        let summary = syncOutbox.summary()
        syncOutboxPendingCount = summary.pendingCount
        syncOutboxPermanentFailureCount = summary.permanentFailureCount
        syncOutboxLastErrorCodeText = summary.lastErrorCode?.rawValue ?? ""

        if let previous,
           previous.pendingCount > 0,
           previous.lastErrorCode == .offline,
           summary.pendingCount == 0,
           summary.lastErrorCode == nil {
            syncRecoveryToastMessage = "온라인 복구: 대기 중 기록 동기화를 완료했어요."
        }
        lastSyncSummarySnapshot = summary
    }

    private func enqueueSyncOutbox(for polygon: Polygon, hasImage: Bool) {
        guard isCloudSyncAvailableForSession else { return }
        guard let sessionDTO = WalkBackfillDTOConverter.makeSessionDTO(
            from: polygon,
            ownerUserId: currentMetricUserId(),
            petId: polygon.petId,
            sourceDevice: "ios",
            hasImage: hasImage
        ) else { return }
        syncOutbox.enqueueWalkStages(sessionDTO: sessionDTO)
        refreshSyncOutboxSummary()
        flushSyncOutboxIfNeeded(force: true)
    }

    private func flushSyncOutboxIfNeeded(force: Bool = false) {
        let now = Date()
        if force == false, now.timeIntervalSince(lastSyncFlushAt) < 5.0 {
            return
        }
        guard syncFlushTask == nil else { return }
        lastSyncFlushAt = now
        syncFlushTask = Task { [weak self] in
            guard let self else { return }
            let summary = await syncOutbox.flush(using: syncTransport, now: Date())
            await MainActor.run {
                let previous = self.lastSyncSummarySnapshot
                self.syncOutboxPendingCount = summary.pendingCount
                self.syncOutboxPermanentFailureCount = summary.permanentFailureCount
                self.syncOutboxLastErrorCodeText = summary.lastErrorCode?.rawValue ?? ""
                if let previous,
                   previous.pendingCount > 0,
                   previous.lastErrorCode == .offline,
                   summary.pendingCount == 0,
                   summary.lastErrorCode == nil {
                    self.syncRecoveryToastMessage = "온라인 복구: 대기 중 기록 동기화를 완료했어요."
                }
                self.lastSyncSummarySnapshot = summary
                self.syncFlushTask = nil
            }
        }
    }

    private static let statusTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static func statusTimeString(from date: Date) -> String {
        statusTimeFormatter.string(from: date)
    }

    private func setRuntimeGuardStatus(_ message: String) {
        runtimeGuardStatusText = "\(Self.statusTimeString(from: Date())) \(message)"
        triggerWarningHapticIfNeeded()
    }

    var isMapMotionReduced: Bool {
        #if canImport(UIKit)
        return mapMotionReduced || UIAccessibility.isReduceMotionEnabled
        #else
        return mapMotionReduced
        #endif
    }

    func toggleMapMotionReduced() {
        mapMotionReduced.toggle()
        preferenceStore.set(mapMotionReduced, forKey: mapMotionReducedKey)
    }

    var weatherOverlayTintColor: Color {
        switch weatherOverlayRiskLevel {
        case .clear: return .clear
        case .caution: return Color.appYellowPale
        case .bad: return Color.appPeach
        case .severe: return Color.appRed
        }
    }

    var weatherOverlayAnimationDuration: Double {
        isMapMotionReduced ? 0.18 : 0.42
    }

    var clusterMotionAnimationDuration: Double {
        isMapMotionReduced ? 0.14 : 0.28
    }

    var captureRippleDuration: Double {
        isMapMotionReduced ? 0.35 : 0.52
    }

    var activeTrailMarkers: [TrailMarker] {
        guard isWalking else { return [] }
        let now = Date().timeIntervalSince1970
        return Array(
            polygon.locations
            .suffix(trailLimit * 2)
            .reversed()
            .compactMap { point in
                let age = max(0, now - point.createdAt)
                guard age <= trailLifetime else { return nil }
                return TrailMarker(id: point.id, coordinate: point.coordinate, age: age)
            }
            .prefix(trailLimit)
            .map { $0 }
            .reversed()
        )
    }

    func activeCaptureRipples(at now: Date = Date()) -> [CaptureRipple] {
        let nowTs = now.timeIntervalSince1970
        return captureRipples.filter { nowTs - $0.createdAt <= captureRippleDuration }
    }

    func captureRippleProgress(for ripple: CaptureRipple, now: Date = Date()) -> Double {
        let elapsed = max(0, now.timeIntervalSince1970 - ripple.createdAt)
        return min(1.0, elapsed / max(0.001, captureRippleDuration))
    }

    func compactMapMotionArtifacts(now: Date = Date()) {
        let valid = activeCaptureRipples(at: now)
        if valid.count != captureRipples.count {
            captureRipples = valid
        }
    }

    private func pushCaptureRipple(at coordinate: CLLocationCoordinate2D, source: PointAppendSource) {
        let ripple = CaptureRipple(coordinate: coordinate)
        captureRipples.append(ripple)
        if captureRipples.count > maxCaptureRipples {
            captureRipples.removeFirst(captureRipples.count - maxCaptureRipples)
        }
        if source != .auto {
            triggerCaptureHapticIfNeeded()
        }
    }

    private func triggerCaptureHapticIfNeeded(now: Date = Date()) {
        guard now.timeIntervalSince(lastCaptureHapticAt) >= 0.08 else { return }
        lastCaptureHapticAt = now
        AppHapticFeedback.mapCaptureSuccess(reducedMotion: isMapMotionReduced)
    }

    private func triggerWarningHapticIfNeeded(now: Date = Date()) {
        guard now.timeIntervalSince(lastWarningHapticAt) >= 1.2 else { return }
        lastWarningHapticAt = now
        AppHapticFeedback.mapWarning()
    }

    private func validateWalkLocationSample(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= locationAccuracyThreshold else {
            setRuntimeGuardStatus("저정확도 GPS 샘플 폐기")
            return false
        }

        if let last = lastAcceptedWalkLocation {
            let delta = max(0.001, location.timestamp.timeIntervalSince(last.timestamp))
            let distance = location.distance(from: last)
            let speed = distance / delta
            let isJumpBySpeed = speed > jumpSpeedThreshold && distance > autoRecordNoiseDistance
            let isJumpByDistance = distance > jumpDistanceThreshold && delta <= jumpTimeWindow
            if isJumpBySpeed || isJumpByDistance {
                setRuntimeGuardStatus("비정상 점프 포인트 폐기")
                return false
            }
        }

        lastAcceptedWalkLocation = location
        return true
    }

    private func resetInactivityTracking(now: Date, clearAnchor: Bool) {
        lastMovementAt = now
        if clearAnchor {
            movementAnchorLocation = nil
        }
        didNotifyRestCandidate = false
        didNotifyInactivityWarning = false
    }

    private func updateMovementState(with location: CLLocation) {
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= inactivityAccuracyThreshold else {
            return
        }
        guard let anchor = movementAnchorLocation else {
            movementAnchorLocation = location
            lastMovementAt = location.timestamp
            return
        }
        let distance = location.distance(from: anchor)
        let speedCandidate = location.speed >= 0 ? location.speed : max(0, distance / max(1, location.timestamp.timeIntervalSince(anchor.timestamp)))
        let isMoving = speedCandidate >= inactivitySpeedThreshold || distance >= inactivityDistanceThreshold
        if isMoving {
            movementAnchorLocation = location
            resetInactivityTracking(now: location.timestamp, clearAnchor: false)
        }
    }

    private func pauseWalkForAuthorizationDowngrade() {
        guard isWalking else { return }
        timerStop()
        persistActiveWalkSession(force: true)
        prepareRecoverableSessionIfNeeded()
        withAnimation { [weak self] in
            self?.isWalking = false
        }
        syncWatchContext(force: true)
        walkStatusMessage = "위치 권한이 해제되어 산책을 안전 일시중지했습니다."
        setRuntimeGuardStatus("권한 강등 감지로 세션 일시중지")
    }

    private func prepareRecoverableSessionIfNeeded() {
        guard let snapshot = decodeActiveWalkSession() else { return }
        guard Date().timeIntervalSince1970 - snapshot.savedAt <= recoverableSessionMaxAge else {
            clearActiveWalkSession()
            return
        }
        guard snapshot.elapsedTime > 0 || snapshot.points.isEmpty == false else {
            clearActiveWalkSession()
            return
        }
        let now = Date()
        pendingRecoverableSession = snapshot
        hasRecoverableWalkSession = true
        recoverableWalkSummaryText = "미종료 산책 \(Int(snapshot.elapsedTime))초 · 포인트 \(snapshot.points.count)개"
        recoverableWalkEstimateText = recoverableFinalizationEstimateText(snapshot: snapshot, now: now)
        metricTracker.track(
            .recoveryDraftDetected,
            userKey: currentMetricUserId(),
            payload: [
                "pointCount": "\(snapshot.points.count)",
                "elapsedSec": "\(Int(snapshot.elapsedTime))"
            ]
        )
    }

    private func recoverableFinalizationEstimate(
        snapshot: ActiveWalkSessionSnapshot,
        now: Date
    ) -> (endedAt: TimeInterval?, source: String) {
        let lastMovementAt = snapshotLastMovementTime(snapshot)
        let inactivity = now.timeIntervalSince(lastMovementAt)
        if inactivity < restCandidateInterval {
            return (nil, "resume_recommended")
        }
        let estimated = min(now.timeIntervalSince1970, lastMovementAt.timeIntervalSince1970 + inactivityFinalizeInterval)
        return (max(snapshot.startedAt, estimated), "last_movement_plus_threshold")
    }

    private func recoverableFinalizationEstimateText(
        snapshot: ActiveWalkSessionSnapshot,
        now: Date
    ) -> String {
        let estimate = recoverableFinalizationEstimate(snapshot: snapshot, now: now)
        guard let endedAt = estimate.endedAt else {
            return "최근 이동이 감지되어 세션 복구를 권장해요."
        }
        return "추정 종료 시각 \(Self.statusTimeString(from: Date(timeIntervalSince1970: endedAt))) (마지막 이동 + 15분)"
    }

    private func snapshotLastMovementTime(_ snapshot: ActiveWalkSessionSnapshot) -> Date {
        if let lastMovementAt = snapshot.lastMovementAt {
            return Date(timeIntervalSince1970: lastMovementAt)
        }
        if let lastPointAt = snapshot.points.last?.createdAt {
            return Date(timeIntervalSince1970: lastPointAt)
        }
        return Date(timeIntervalSince1970: snapshot.startedAt + snapshot.elapsedTime)
    }

    func resumeRecoverableWalkSession() {
        resumeRecoverableWalkSession(autoRecovered: false)
    }

    private func resumeRecoverableWalkSession(autoRecovered: Bool) {
        guard let snapshot = pendingRecoverableSession, isWalking == false else { return }

        let restoredPoints = snapshot.points.map {
            Location(
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                id: UUID(),
                createdAt: $0.createdAt
            )
        }

        polygon = Polygon(
            locations: restoredPoints,
            walkingTime: snapshot.elapsedTime,
            walkingArea: 0.0,
            petId: snapshot.selectedPetId
        )
        if let sessionId = snapshot.sessionId, let restoredId = UUID(uuidString: sessionId) {
            polygon.id = restoredId
        }
        time = snapshot.elapsedTime
        startTime = Date().addingTimeInterval(-snapshot.elapsedTime)
        if restoredPoints.count > 2 {
            makePolygon()
        }

        if let selectedPetId = snapshot.selectedPetId {
            userSessionStore.setSelectedPetId(selectedPetId, source: "walk_recovery")
        }
        reloadSelectedPetContext()
        currentWalkingPetName = snapshot.currentWalkingPetName
        walkPointRecordMode = WalkPointRecordMode(rawValue: snapshot.pointRecordMode) ?? .manual
        userSessionStore.setWalkPointRecordModeRawValue(walkPointRecordMode.rawValue)

        lastPointEventAt = snapshot.points.last.map { Date(timeIntervalSince1970: $0.createdAt) } ?? Date()
        lastMovementAt = snapshot.lastMovementAt.map { Date(timeIntervalSince1970: $0) } ?? lastPointEventAt
        lastAutoRecordedLocation = snapshot.points.last.map {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
        }
        lastAcceptedWalkLocation = lastAutoRecordedLocation
        movementAnchorLocation = lastAutoRecordedLocation
        lastAutoRecordedAt = lastPointEventAt ?? Date()
        didNotifyRestCandidate = false
        didNotifyInactivityWarning = false

        hasRecoverableWalkSession = false
        recoverableWalkSummaryText = ""
        pendingRecoverableSession = nil

        withAnimation { [weak self] in
            self?.isWalking = true
        }
        timerSet()
        persistActiveWalkSession(force: true)
        walkStatusMessage = autoRecovered ? "산책 세션을 자동 복구했습니다." : "이전 산책 세션을 복구했습니다."
        setRuntimeGuardStatus("세션 복구 완료")
        syncWatchContext(force: true)
    }

    func discardRecoverableWalkSession() {
        metricTracker.track(
            .recoveryDraftDiscarded,
            userKey: currentMetricUserId(),
            payload: [:]
        )
        pendingRecoverableSession = nil
        hasRecoverableWalkSession = false
        recoverableWalkSummaryText = ""
        recoverableWalkEstimateText = ""
        clearActiveWalkSession()
    }

    func finalizeRecoverableWalkSessionEstimated() {
        guard let snapshot = pendingRecoverableSession else {
            clearActiveWalkSession()
            return
        }
        let estimate = recoverableFinalizationEstimate(snapshot: snapshot, now: Date())
        guard let endedAt = estimate.endedAt else {
            walkStatusMessage = "최근 이동이 감지되어 추정 종료를 권장하지 않아요. 복구 후 종료해주세요."
            return
        }
        finalizeRecoverableWalkSession(
            snapshot: snapshot,
            endedAt: endedAt,
            reason: .recoveryEstimated,
            successMessage: "미종료 산책을 추정 종료 시각으로 저장했습니다.",
            metricSource: estimate.source
        )
    }

    func finalizeRecoverableWalkSessionNow() {
        guard let snapshot = pendingRecoverableSession else {
            clearActiveWalkSession()
            return
        }
        finalizeRecoverableWalkSession(
            snapshot: snapshot,
            endedAt: Date().timeIntervalSince1970,
            reason: .manual,
            successMessage: "미종료 산책을 지금 종료로 저장했습니다.",
            metricSource: "manual_now"
        )
    }

    private func finalizeRecoverableWalkSession(
        snapshot: ActiveWalkSessionSnapshot,
        endedAt: TimeInterval,
        reason: WalkSessionEndReason,
        successMessage: String,
        metricSource: String
    ) {
        let restoredPoints = snapshot.points.map {
            Location(
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                id: UUID(),
                createdAt: $0.createdAt
            )
        }
        guard restoredPoints.count > 2 else {
            walkStatusMessage = "포인트 부족으로 종료 확정을 할 수 없어요. 복구 후 계속 기록하거나 폐기해주세요."
            metricTracker.track(
                .recoveryFinalizeFailed,
                userKey: currentMetricUserId(),
                payload: ["reason": "insufficient_points"]
            )
            return
        }
        let finalizedEndAt = max(snapshot.startedAt, endedAt)
        let walkTime = max(0, finalizedEndAt - snapshot.startedAt)
        let restoredSessionId = snapshot.sessionId.flatMap(UUID.init(uuidString:))
        let completed = Polygon(
            locations: restoredPoints,
            createdAt: snapshot.startedAt,
            id: restoredSessionId ?? UUID(),
            walkingTime: walkTime,
            walkingArea: 0.0,
            imgData: nil,
            petId: snapshot.selectedPetId
        )
        var finalized = completed
        finalized.makePolygon(walkArea: calculateArea(points: restoredPoints), walkTime: walkTime)
        let updated = walkRepository.savePolygon(finalized)
        if updated.contains(where: { $0.id == finalized.id }) {
            WalkSessionMetadataStore.shared.set(
                sessionId: finalized.id,
                reason: reason,
                endedAt: finalizedEndAt,
                petId: snapshot.selectedPetId
            )
            enqueueSyncOutbox(for: finalized, hasImage: finalized.binaryImage != nil)
            walkStatusMessage = successMessage
            metricTracker.track(
                .recoveryFinalizeConfirmed,
                userKey: currentMetricUserId(),
                payload: [
                    "mode": reason.rawValue,
                    "source": metricSource,
                    "endedAt": "\(Int(finalizedEndAt))"
                ]
            )
            applyPolygonList(updated)
            clearActiveWalkSession()
        } else {
            walkStatusMessage = "미종료 산책 종료 저장에 실패했습니다."
            metricTracker.track(
                .recoveryFinalizeFailed,
                userKey: currentMetricUserId(),
                payload: ["reason": "local_save_failed"]
            )
        }
    }

    private func decodeActiveWalkSession() -> ActiveWalkSessionSnapshot? {
        guard let data = preferenceStore.data(forKey: activeWalkSessionStorageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(ActiveWalkSessionSnapshot.self, from: data)
    }

    private func persistActiveWalkSession(force: Bool = false) {
        guard isWalking else { return }
        let now = Date()
        if force == false, now.timeIntervalSince(lastSnapshotPersistAt) < 10.0 {
            return
        }

        let snapshot = ActiveWalkSessionSnapshot(
            sessionId: polygon.id.uuidString.lowercased(),
            startedAt: startTime.timeIntervalSince1970,
            elapsedTime: time,
            selectedPetId: selectedPetId,
            selectedPetName: selectedPetName,
            currentWalkingPetName: currentWalkingPetName,
            pointRecordMode: walkPointRecordMode.rawValue,
            lastMovementAt: lastMovementAt?.timeIntervalSince1970,
            points: polygon.locations.map {
                ActiveWalkPointSnapshot(
                    latitude: $0.coordinate.latitude,
                    longitude: $0.coordinate.longitude,
                    createdAt: $0.createdAt
                )
            },
            savedAt: now.timeIntervalSince1970
        )

        if let data = try? JSONEncoder().encode(snapshot) {
            preferenceStore.set(data, forKey: activeWalkSessionStorageKey)
            lastSnapshotPersistAt = now
        }
    }

    private func clearActiveWalkSession() {
        preferenceStore.removeObject(forKey: activeWalkSessionStorageKey)
        pendingRecoverableSession = nil
        hasRecoverableWalkSession = false
        recoverableWalkSummaryText = ""
        recoverableWalkEstimateText = ""
        lastPointEventAt = nil
        lastMovementAt = nil
        movementAnchorLocation = nil
        didNotifyRestCandidate = false
        didNotifyInactivityWarning = false
        lastAcceptedWalkLocation = nil
    }

    private func handleAutoEndIfNeeded(now: Date = Date()) {
        guard isWalking else { return }
        let baseline = lastMovementAt ?? lastPointEventAt ?? startTime
        let inactivity = now.timeIntervalSince(baseline)

        if inactivity >= inactivityFinalizeInterval {
            let endedAt = min(now.timeIntervalSince1970, baseline.timeIntervalSince1970 + inactivityFinalizeInterval)
            if polygon.locations.count > 2 {
                endWalk(reason: .autoInactive, endedAtOverride: Date(timeIntervalSince1970: endedAt))
                walkStatusMessage = "15분 무이동으로 산책을 자동 종료했습니다."
                triggerWarningHapticIfNeeded()
            } else {
                discardCurrentWalk()
                walkStatusMessage = "15분 무이동으로 산책 임시기록을 폐기했습니다."
                triggerWarningHapticIfNeeded()
            }
            return
        }

        if inactivity >= inactivityWarningInterval, didNotifyInactivityWarning == false {
            didNotifyInactivityWarning = true
            walkStatusMessage = "12분 무이동: 3분 후 자동 종료 예정입니다."
            triggerWarningHapticIfNeeded()
            return
        }

        if inactivity >= restCandidateInterval, didNotifyRestCandidate == false {
            didNotifyRestCandidate = true
            walkStatusMessage = "5분 무이동: 휴식 상태로 감지했습니다."
        }
    }

    private func setupLifecycleObservers() {
        #if canImport(UIKit)
        let didBecomeActive = eventCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flushSyncOutboxIfNeeded(force: true)
            self?.syncVisibilitySettingIfNeeded()
            self?.refreshWeatherOverlayRisk()
        }
        let willResign = eventCenter.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.persistActiveWalkSession(force: true)
        }
        let willTerminate = eventCenter.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.persistActiveWalkSession(force: true)
        }
        let petContextChanged = eventCenter.addObserver(
            forName: UserdefaultSetting.selectedPetDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadSelectedPetContext()
        }
        #if canImport(UIKit)
        let reduceMotionChanged = eventCenter.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
            self?.refreshWeatherOverlayRisk()
        }
        lifecycleObservers = [didBecomeActive, willResign, willTerminate, petContextChanged, reduceMotionChanged]
        #else
        lifecycleObservers = [didBecomeActive, willResign, willTerminate, petContextChanged]
        #endif
        #endif
    }

    private func appendWalkPoint(from location: CLLocation, recordedAt: Date, source: PointAppendSource) {
        polygon.addPoint(.init(coordinate: location.coordinate))
        pushCaptureRipple(at: location.coordinate, source: source)
        lastAutoRecordedLocation = location
        lastAutoRecordedAt = recordedAt
        lastPointEventAt = recordedAt
        movementAnchorLocation = location
        resetInactivityTracking(now: recordedAt, clearAnchor: false)
        if source == .watch {
            latestWatchActionText = "워치 포인트 반영 \(Self.statusTimeString(from: recordedAt))"
        }
        persistActiveWalkSession(force: true)
        syncWatchContext(force: true)
        compactMapMotionArtifacts(now: recordedAt)
        eventCenter.post(
            name: .walkPointRecordedForQuest,
            object: nil,
            userInfo: [
                "source": "\(source)",
                "recordedAt": recordedAt.timeIntervalSince1970
            ]
        )
    }

    private func resetAutoPointRecordState() {
        lastAutoRecordedLocation = nil
        lastAutoRecordedAt = .distantPast
    }

    private func handleAutoPointRecord(with location: CLLocation) {
        guard isWalking, walkPointRecordMode == .auto else { return }
        let now = Date()

        if polygon.locations.isEmpty {
            appendWalkPoint(from: location, recordedAt: now, source: .auto)
            return
        }

        if let lastPoint = polygon.locations.last {
            let lastPointLocation = CLLocation(
                latitude: lastPoint.coordinate.latitude,
                longitude: lastPoint.coordinate.longitude
            )
            if location.distance(from: lastPointLocation) < autoRecordNoiseDistance {
                return
            }
        }

        if let lastAutoRecordedLocation {
            let moved = location.distance(from: lastAutoRecordedLocation)
            let elapsed = now.timeIntervalSince(lastAutoRecordedAt)
            guard moved >= autoRecordMinDistance, elapsed >= autoRecordMinInterval else {
                return
            }
        }

        appendWalkPoint(from: location, recordedAt: now, source: .auto)
    }
    func setTrackingMode() {
        guard let location = self.location else {
            withAnimation(.easeInOut(duration: 0.3)){ [weak self] in
                self?.cameraPosition = MapCameraPosition.userLocation(followsHeading: true, fallback: .automatic)
            }
            return }
        withAnimation(.easeInOut(duration: 0.3)){ [weak self] in
            self?.cameraPosition = MapCameraPosition.userLocation(followsHeading: true, fallback: MapCameraPosition.camera(.init(centerCoordinate: location.coordinate, distance: 2000)))
        }

    }
    private func forceQuit() {
        endWalk(reason: .autoTimeout)
        walkStatusMessage = "최대 산책 시간 도달로 자동 종료했습니다."
    }

    func deletePolygonAndRefresh(_ id: UUID) {
        WalkSessionMetadataStore.shared.clear(sessionId: id)
        let updated = walkRepository.deletePolygon(id: id)
        self.applyPolygonList(updated)
    }

    func refreshHeatmap(now: Date = Date()) {
        guard isHeatmapFeatureAvailable else {
            self.heatmapCells = []
            return
        }
        let points = self.polygonList.flatMap { $0.locations }
        self.heatmapCells = HeatmapEngine.aggregate(points: points, now: now, precision: 7)
    }

    var isHeatmapFeatureAvailable: Bool {
        featureFlags.isEnabled(.heatmapV1)
    }

    var isCloudSyncAvailableForSession: Bool {
        AppFeatureGate.isAllowed(.cloudSync)
    }

    var isNearbySocialAvailableForSession: Bool {
        AppFeatureGate.isAllowed(.nearbySocial)
    }

    var isNearbyHotspotFeatureAvailable: Bool {
        featureFlags.isEnabled(.nearbyHotspotV1) && isNearbySocialAvailableForSession
    }

    private func lodIntValue(key: String, defaultValue: Int) -> Int {
        preferenceStore.integer(forKey: key, default: defaultValue)
    }

    private func lodDoubleValue(key: String, defaultValue: Double) -> Double {
        preferenceStore.double(forKey: key, default: defaultValue)
    }

    private var overlayMaxCameraDistance: Double {
        lodDoubleValue(
            key: MapOverlayLODTuning.overlayMaxCameraDistanceKey,
            defaultValue: MapOverlayLODTuning.overlayMaxCameraDistanceDefault
        )
    }

    private var overlayClusterThreshold: Int {
        lodIntValue(
            key: MapOverlayLODTuning.overlayClusterThresholdKey,
            defaultValue: MapOverlayLODTuning.overlayClusterThresholdDefault
        )
    }

    private var overlayPolygonCountThreshold: Int {
        lodIntValue(
            key: MapOverlayLODTuning.overlayPolygonCountThresholdKey,
            defaultValue: MapOverlayLODTuning.overlayPolygonCountThresholdDefault
        )
    }

    private var singleClusterOverlayLimit: Int {
        lodIntValue(
            key: MapOverlayLODTuning.singleClusterOverlayLimitKey,
            defaultValue: MapOverlayLODTuning.singleClusterOverlayLimitDefault
        )
    }

    private var clusterCellDistanceRatio: Double {
        lodDoubleValue(
            key: MapOverlayLODTuning.clusterCellDistanceRatioKey,
            defaultValue: MapOverlayLODTuning.clusterCellDistanceRatioDefault
        )
    }

    private var clusterCellMinMeters: Double {
        lodDoubleValue(
            key: MapOverlayLODTuning.clusterCellMinMetersKey,
            defaultValue: MapOverlayLODTuning.clusterCellMinMetersDefault
        )
    }

    private var clusterCellMaxMeters: Double {
        lodDoubleValue(
            key: MapOverlayLODTuning.clusterCellMaxMetersKey,
            defaultValue: MapOverlayLODTuning.clusterCellMaxMetersDefault
        )
    }

    var shouldRenderFullPolygonOverlays: Bool {
        guard showOnlyOne == false else { return true }
        guard currentCameraDistance <= overlayMaxCameraDistance else { return false }
        guard centerLocations.count <= overlayClusterThreshold else { return false }
        guard polygonList.count <= overlayPolygonCountThreshold else { return false }
        return true
    }

    var renderablePolygonOverlays: [Polygon] {
        guard showOnlyOne == false else { return polygonList }
        guard shouldRenderFullPolygonOverlays == false else { return polygonList }

        let singleClusterIds: [UUID] = centerLocations.compactMap { cluster -> UUID? in
            guard cluster.sumLocs.count == 1 else { return nil }
            return cluster.sumLocs.first?.1
        }

        guard singleClusterIds.isEmpty == false else { return [] }
        let allowedIds = Set(singleClusterIds.prefix(singleClusterOverlayLimit))
        return polygonList.filter { allowedIds.contains($0.id) }
    }

    struct SeasonTileLegendItem: Identifiable, Equatable {
        let level: Int
        let label: String
        let status: String

        var id: Int { level }
    }

    func seasonTileIntensityLevel(for score: Double) -> Int {
        guard score > 0 else { return 0 }
        let level = Int(ceil(score * 4.0) - 1.0)
        return min(3, max(0, level))
    }

    func seasonTileStatusText(for score: Double) -> String {
        score >= 0.55 ? "점령" : "유지"
    }

    var seasonTileLegendItems: [SeasonTileLegendItem] {
        [
            .init(level: 0, label: "1단계", status: "유지"),
            .init(level: 1, label: "2단계", status: "유지"),
            .init(level: 2, label: "3단계", status: "점령"),
            .init(level: 3, label: "4단계", status: "점령")
        ]
    }

    var seasonOccupiedTileCount: Int {
        heatmapCells.filter { seasonTileStatusText(for: $0.score) == "점령" }.count
    }

    var seasonMaintainedTileCount: Int {
        heatmapCells.filter { seasonTileStatusText(for: $0.score) == "유지" }.count
    }

    var seasonTileStatusSummaryText: String {
        "시즌 타일 4단계 · 점령 \(seasonOccupiedTileCount) · 유지 \(seasonMaintainedTileCount)"
    }

    func heatmapColor(for score: Double) -> Color {
        let level = seasonTileIntensityLevel(for: score)
        let status = seasonTileStatusText(for: score)
        switch (level, status) {
        case (0, _): return Color.appGreen
        case (1, _): return Color.appYellowPale
        case (2, "점령"): return Color.appPeach
        case (2, _): return Color.appYellow
        case (3, "점령"): return Color.appRed
        default: return Color.appPeach
        }
    }

    func heatmapOpacity(for score: Double) -> Double {
        switch seasonTileIntensityLevel(for: score) {
        case 0: return 0.28
        case 1: return 0.38
        case 2: return 0.50
        default: return 0.62
        }
    }

    func nearbyHotspotColor(for intensity: Double) -> Color {
        switch intensity {
        case ..<0.2: return Color.appGreen
        case ..<0.4: return Color.appYellowPale
        case ..<0.6: return Color.appYellow
        case ..<0.8: return Color.appPeach
        default: return Color.appRed
        }
    }

    func nearbyHotspotOpacity(for intensity: Double) -> Double {
        switch intensity {
        case ..<0.2: return 0.22
        case ..<0.4: return 0.30
        case ..<0.6: return 0.40
        case ..<0.8: return 0.50
        default: return 0.60
        }
    }

    func toggleHeatmapEnabled() {
        guard isHeatmapFeatureAvailable else {
            self.heatmapEnabled = false
            self.heatmapCells = []
            return
        }
        self.heatmapEnabled.toggle()
        preferenceStore.set(self.heatmapEnabled, forKey: heatmapEnabledKey)
        if self.heatmapEnabled {
            refreshHeatmap()
        } else {
            self.heatmapCells = []
        }
    }

    func toggleLocationSharing() {
        guard isNearbyHotspotFeatureAvailable else {
            self.locationSharingEnabled = false
            preferenceStore.set(false, forKey: locationSharingKey)
            self.syncVisibilitySettingIfNeeded()
            return
        }
        self.locationSharingEnabled.toggle()
        preferenceStore.set(self.locationSharingEnabled, forKey: locationSharingKey)
        metricTracker.track(
            self.locationSharingEnabled ? .nearbyOptInEnabled : .nearbyOptInDisabled,
            userKey: currentMetricUserId(),
            featureKey: .nearbyHotspotV1
        )
        self.syncVisibilitySettingIfNeeded()
    }

    func toggleNearbyHotspotEnabled() {
        guard isNearbyHotspotFeatureAvailable else {
            self.nearbyHotspotEnabled = false
            self.nearbyHotspots = []
            preferenceStore.set(false, forKey: nearbyHotspotEnabledKey)
            return
        }
        self.nearbyHotspotEnabled.toggle()
        preferenceStore.set(self.nearbyHotspotEnabled, forKey: nearbyHotspotEnabledKey)
        if nearbyHotspotEnabled == false {
            self.nearbyHotspots = []
        }
    }

    private func startNearbyTicker() {
        nearbyTickTimer?.invalidate()
        nearbyTickTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.nearbyTick()
        }
    }

    private func nearbyTick() {
        flushSyncOutboxIfNeeded()
        refreshWeatherOverlayRisk()
        guard let location else { return }
        let now = Date()

        if isNearbyHotspotFeatureAvailable && locationSharingEnabled && isWalking && now.timeIntervalSince(lastPresenceSentAt) >= 30 {
            lastPresenceSentAt = now
            sendPresence(location: location.coordinate)
        }

        if isNearbyHotspotFeatureAvailable && nearbyHotspotEnabled && now.timeIntervalSince(lastNearbyFetchedAt) >= 10 {
            lastNearbyFetchedAt = now
            fetchNearbyHotspots(center: location.coordinate)
        }
    }

    private func sendPresence(location: CLLocationCoordinate2D) {
        guard let userId = currentPresenceUserId() else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.nearbyService.upsertPresence(
                    userId: userId,
                    latitude: location.latitude,
                    longitude: location.longitude
                )
            } catch {
                print("presence upsert failed: \(error.localizedDescription)")
            }
        }
    }
    private func publishWatchState() {
        guard let watchSession else { return }
        let context: [String: Any] = [
            "isWalking": isWalking,
            "time": time,
            "area": calculateArea()
        ]
        try? watchSession.updateApplicationContext(context)
    }
    private func applyWatchAction(_ action: String) {
        switch action {
        case "startWalk":
            if !isWalking {
                endWalk()
            }
        case "addPoint":
            if isWalking {
                addLocation()
                makePolygon()
            }
        case "endWalk":
            if isWalking {
                timerStop()
                endWalk()
            }
        default:
            break
        }
    }

    private func fetchNearbyHotspots(center: CLLocationCoordinate2D) {
        let userId = currentPresenceUserId()
        Task { [weak self] in
            guard let self else { return }
            do {
                let hotspots = try await nearbyService.getHotspots(
                    userId: userId,
                    centerLatitude: center.latitude,
                    centerLongitude: center.longitude,
                    radiusKm: 1.0
                )
                await MainActor.run {
                    self.nearbyHotspots = hotspots
                }
            } catch {
                print("nearby hotspot fetch failed: \(error.localizedDescription)")
            }
        }
    }

    private func syncVisibilitySettingIfNeeded() {
        guard let userId = currentPresenceUserId() else { return }
        let enabled = isNearbyHotspotFeatureAvailable ? self.locationSharingEnabled : false
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.nearbyService.setVisibility(userId: userId, enabled: enabled)
                if enabled == false {
                    await MainActor.run {
                        self.nearbyHotspots = []
                    }
                }
            } catch {
                print("visibility sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func refreshFeatureFlagsFromRemote() {
        Task { [weak self] in
            guard let self else { return }
            _ = await self.featureFlags.refresh()
            await MainActor.run {
                self.applyFeatureFlags()
            }
        }
    }

    private func applyFeatureFlags() {
        let heatmapAllowed = featureFlags.isEnabled(.heatmapV1)
        let nearbyAllowed = featureFlags.isEnabled(.nearbyHotspotV1)
        let nearbyAllowedForSession = nearbyAllowed && isNearbySocialAvailableForSession
        let heatmapPreference = preferenceStore.bool(forKey: heatmapEnabledKey, default: true)
        let nearbyPreference = preferenceStore.bool(forKey: nearbyHotspotEnabledKey, default: true)
        let sharingPreference = preferenceStore.bool(forKey: locationSharingKey, default: false)

        self.heatmapEnabled = heatmapAllowed ? heatmapPreference : false
        self.nearbyHotspotEnabled = nearbyAllowedForSession ? nearbyPreference : false
        self.locationSharingEnabled = nearbyAllowedForSession ? sharingPreference : false

        if heatmapAllowed {
            self.refreshHeatmap()
        } else {
            self.heatmapCells = []
        }

        if nearbyAllowedForSession == false {
            self.nearbyHotspots = []
            preferenceStore.set(false, forKey: locationSharingKey)
            self.syncVisibilitySettingIfNeeded()
        }
    }

    private func resolveWeatherOverlayRiskFromDefaults() -> (risk: WeatherOverlayRiskLevel, fallback: Bool) {
        if let env = ProcessInfo.processInfo.environment["WEATHER_RISK_LEVEL"],
           let fromEnv = WeatherOverlayRiskLevel(rawValue: env.lowercased()) {
            return (fromEnv, false)
        }
        if let raw = preferenceStore.string(forKey: weatherRiskOverrideKey),
           let fromDefaults = WeatherOverlayRiskLevel(rawValue: raw.lowercased()) {
            return (fromDefaults, false)
        }
        return (.clear, true)
    }

    func refreshWeatherOverlayRisk() {
        let next = resolveWeatherOverlayRiskFromDefaults()
        let nextRisk = next.risk
        weatherOverlayFallbackActive = next.fallback
        weatherOverlayStatusText = next.fallback
            ? "Fallback: 날씨 데이터 연결 불가"
            : "날씨 위험도 \(nextRisk.displayTitle)"
        guard nextRisk != weatherOverlayRiskLevel || (nextRisk == .clear && weatherOverlayOpacity != 0.0) else { return }
        withAnimation(.easeInOut(duration: weatherOverlayAnimationDuration)) {
            weatherOverlayRiskLevel = nextRisk
            weatherOverlayOpacity = nextRisk == .clear ? 0.0 : (isMapMotionReduced ? 0.12 : 0.18)
        }
    }

    private func currentPresenceUserId() -> String? {
        if let authUserId = authSessionStore.currentIdentity()?.userId,
           let canonical = authUserId.canonicalUUIDString {
            preferenceStore.set(canonical, forKey: nearbyPresenceUserIdKey)
            return canonical
        }

        if let existing = preferenceStore.string(forKey: nearbyPresenceUserIdKey),
           let canonical = existing.canonicalUUIDString {
            return canonical
        }

        if let profileUserId = userSessionStore.currentUserInfo()?.id,
           let canonical = profileUserId.canonicalUUIDString {
            preferenceStore.set(canonical, forKey: nearbyPresenceUserIdKey)
            return canonical
        }

        preferenceStore.removeObject(forKey: nearbyPresenceUserIdKey)
        return nil
    }

    private func currentMetricUserId() -> String? {
        guard let raw = userSessionStore.currentUserInfo()?.id, raw.isEmpty == false else {
            return nil
        }
        return raw
    }

    func reloadSelectedPetContext() {
        let userInfo = userSessionStore.currentUserInfo()
        self.availablePets = userInfo?.pet ?? []
        let selectedPet = userSessionStore.selectedPet(from: userInfo)
        self.selectedPetId = selectedPet?.petId
        self.selectedPetName = selectedPet?.petName ?? "강아지"
        if isWalking == false {
            self.currentWalkingPetName = self.selectedPetName
        }
    }

    var hasSelectedPet: Bool {
        selectedPetId != nil
    }

    func prepareWalkPetSelectionSuggestion() {
        guard isWalking == false else { return }
        guard let userInfo = userSessionStore.currentUserInfo(), userInfo.pet.isEmpty == false else {
            reloadSelectedPetContext()
            return
        }
        if let suggested = userSessionStore.suggestedPetForWalkStart(from: userInfo, now: Date()),
           suggested.petId != selectedPetId {
            userSessionStore.setSelectedPetId(suggested.petId, source: "walk_start_suggestion")
            metricTracker.track(
                .petSelectionSuggested,
                userKey: currentMetricUserId(),
                payload: [
                    "petId": suggested.petId,
                    "petName": suggested.petName
                ]
            )
            walkStatusMessage = "\(suggested.petName)을(를) 산책 대상으로 제안했어요."
        }
        reloadSelectedPetContext()
    }

    func cycleSelectedPetForWalkStart() {
        guard isWalking == false else { return }
        guard availablePets.count > 1 else { return }

        let currentIndex = availablePets.firstIndex(where: { $0.petId == selectedPetId }) ?? -1
        let nextIndex = (currentIndex + 1) % availablePets.count
        let nextPet = availablePets[nextIndex]
        userSessionStore.setSelectedPetId(nextPet.petId, source: "walk_start_switcher")
        walkStatusMessage = "산책 대상: \(nextPet.petName)"
        reloadSelectedPetContext()
    }

    private func setupWatchConnectivity() {
        guard let watchSession else { return }
        watchSession.delegate = self
        watchSession.activate()
        self.syncWatchContext(force: true)
    }

    private func syncWatchContext(force: Bool = false) {
        guard let watchSession, watchSession.activationState == .activated else { return }

        let now = Date()
        if force == false, now.timeIntervalSince(lastWatchContextSyncAt) < 1.0 {
            return
        }

        let context: [String: Any] = [
            "version": WatchContract.version,
            "type": "watch_state",
            "isWalking": self.isWalking,
            "time": self.time,
            "area": self.polygon.walkingArea,
            "last_sync_at": now.timeIntervalSince1970,
            "watch_status": self.watchSyncStatusText,
            "last_action_id_applied": self.lastAppliedWatchActionId
        ]

        do {
            try watchSession.updateApplicationContext(context)
            self.lastWatchContextSyncAt = now
            self.watchSyncStatusText = "워치 동기화 \(Self.statusTimeString(from: now))"
        } catch {
            self.watchSyncStatusText = "워치 동기화 실패"
            print("watch context update failed: \(error.localizedDescription)")
        }
    }

    private func loadProcessedWatchActions() {
        let stored = preferenceStore.stringArray(forKey: processedWatchActionStorageKey)
        self.processedWatchActionOrder = stored
        self.processedWatchActionIds = Set(stored)
    }

    private func persistProcessedWatchActions() {
        preferenceStore.set(self.processedWatchActionOrder, forKey: processedWatchActionStorageKey)
    }

    private func shouldProcessWatchAction(actionId: String) -> Bool {
        guard processedWatchActionIds.contains(actionId) == false else {
            return false
        }
        processedWatchActionIds.insert(actionId)
        processedWatchActionOrder.append(actionId)
        if processedWatchActionOrder.count > maxProcessedWatchActions {
            let overflow = processedWatchActionOrder.count - maxProcessedWatchActions
            let removed = Array(processedWatchActionOrder.prefix(overflow))
            processedWatchActionOrder.removeFirst(overflow)
            removed.forEach { processedWatchActionIds.remove($0) }
        }
        persistProcessedWatchActions()
        return true
    }

    @discardableResult
    private func handleWatchPayload(_ payload: [String: Any]) -> [String: Any]? {
        guard let envelope = parseWatchEnvelope(from: payload) else { return nil }
        let actionName = envelope.action.rawValue
        let sentAtLabel: String = {
            guard let sentAt = envelope.sentAt else { return "" }
            return " sent:\(Int(sentAt))"
        }()
        latestWatchActionText = "워치 \(actionName) 수신 \(Self.statusTimeString(from: Date()))"
        metricTracker.track(
            .watchActionReceived,
            userKey: currentMetricUserId(),
            payload: [
                "action": actionName,
                "version": envelope.version + sentAtLabel
            ]
        )
        if shouldProcessWatchAction(actionId: envelope.actionId) == false {
            metricTracker.track(
                .watchActionDuplicate,
                userKey: currentMetricUserId(),
                payload: [
                    "action": actionName,
                    "actionId": envelope.actionId
                ]
            )
            return [
                "version": WatchContract.version,
                "type": WatchContract.ackType,
                "status": "duplicate",
                "action": actionName,
                "action_id": envelope.actionId,
                "last_sync_at": Date().timeIntervalSince1970
            ]
        }
        metricTracker.track(
            .watchActionProcessed,
            userKey: currentMetricUserId(),
            payload: [
                "action": actionName,
                "actionId": envelope.actionId
            ]
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyWatchAction(envelope)
        }
        return [
            "version": WatchContract.version,
            "type": WatchContract.ackType,
            "status": "accepted",
            "action": actionName,
            "action_id": envelope.actionId,
            "last_sync_at": Date().timeIntervalSince1970
        ]
    }

    private func parseWatchEnvelope(from payload: [String: Any]) -> WatchActionEnvelope? {
        let version = (payload["version"] as? String) ?? "watch.legacy.v0"
        if let type = payload["type"] as? String,
           type.isEmpty == false,
           type != WatchContract.actionType {
            return nil
        }
        let nestedPayload = payload["payload"] as? [String: Any]
        let actionPayload = nestedPayload ?? payload

        guard let rawAction = (actionPayload["action"] as? String) ?? (payload["action"] as? String),
              let action = WatchIncomingAction(rawValue: rawAction) else {
            return nil
        }
        let actionId: String = {
            if let id = (actionPayload["action_id"] as? String) ?? (payload["action_id"] as? String),
               id.isEmpty == false {
                return id
            }
            if let sentAt = (actionPayload["sent_at"] as? TimeInterval) ?? (payload["sent_at"] as? TimeInterval) {
                return "\(rawAction):\(Int(sentAt * 1000.0))"
            }
            return UUID().uuidString.lowercased()
        }()
        let sentAt = (actionPayload["sent_at"] as? TimeInterval) ?? (payload["sent_at"] as? TimeInterval)
        return WatchActionEnvelope(version: version, action: action, actionId: actionId, sentAt: sentAt)
    }

    private func applyWatchAction(_ envelope: WatchActionEnvelope) {
        let action = envelope.action
        switch action {
        case .startWalk:
            if self.isWalking == false {
                self.startWalkNow()
                self.latestWatchActionText = "워치 시작 반영 \(Self.statusTimeString(from: Date()))"
                self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action.rawValue])
            }
        case .addPoint:
            if self.isWalking {
                if let location = self.location {
                    self.appendWalkPoint(from: location, recordedAt: Date(), source: .watch)
                    self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action.rawValue])
                }
            }
        case .endWalk:
            if self.isWalking {
                self.endWalk()
                self.latestWatchActionText = "워치 종료 반영 \(Self.statusTimeString(from: Date()))"
                self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action.rawValue])
            }
        case .syncState:
            self.latestWatchActionText = "워치 상태 재동기화 \(Self.statusTimeString(from: Date()))"
        }
        self.lastAppliedWatchActionId = envelope.actionId
        self.syncWatchContext(force: true)
    }

}
//MARK: - 넓이와 시간로직
extension MapViewModel {
    func timerSet() {
        timerStop()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {[weak self] _ in
            guard let self = self else {return}
            guard self.isWalking else { return }
            self.time = max(0, Date().timeIntervalSince(self.startTime))
            self.persistActiveWalkSession()
            self.syncWatchContext()
            if self.time >= self.walkAutoTimeoutInterval {
                self.forceQuit()
                return
            }
            self.handleAutoEndIfNeeded()
        }
    }
    func timerStop() {
        timer?.invalidate()
        timer = nil
    }
    func calculateArea() -> Double {
         let points = self.polygon.locations
        return calculateArea(points: points)
    }

    func calculateArea(points: [Location]) -> Double {
        guard points.count >= 3 else {return 0}
        let earthRadius = 6371000.0  // in meters
        var area: Double = 0
        for i in 0..<points.count {
            let currentPoint = points[i]
            let nextPoint = points[(i + 1) % points.count]
            
            let latitude1 = currentPoint.coordinate.latitude * .pi / 180
            let longitude1 = currentPoint.coordinate.longitude * .pi / 180
            let latitude2 = nextPoint.coordinate.latitude * .pi / 180
            let longitude2 = nextPoint.coordinate.longitude * .pi / 180
            
            let x1 = earthRadius * cos(latitude1) * cos(longitude1)
            let y1 = earthRadius * cos(latitude1) * sin(longitude1)
            let x2 = earthRadius * cos(latitude2) * cos(longitude2)
            let y2 = earthRadius * cos(latitude2) * sin(longitude2)
            
            area += (x1 * y2 - x2 * y1) / 2
        }
        return abs(area)
    }
    func calculatedAreaString(areaSize: Double? = nil , isPyong: Bool = false) -> String {
        let area = areaSize ?? calculateArea()
        var str = String(format: "%.2f" , area) + "㎡"
        if area > 10000.0 {
            str = String(format: "%.2f" , area/10000) + "만 ㎡"
        }
        if area > 100000.0 {
            str = String(format: "%.2f" , area/1000000) + "k㎡"
        }
        if isPyong {
            if area/3.3 > 10000 {
                str = String(format: "%.1f" , area/33333) + "만 평"
            } else {
                str = String(format: "%.1f" , area/3.3) + "평"
            }
        }
        return str
    }
}
//MARK: - CLLocation 관련 로직
extension MapViewModel {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .restricted, .denied:
            pauseWalkForAuthorizationDowngrade()
        case .authorizedAlways, .authorizedWhenInUse:
            if isWalking {
                syncWatchContext(force: true)
            }
            
        @unknown default:
            locationManager.requestAlwaysAuthorization()
        }
    }
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
//        print(manager.location?.description)
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isWalking {
                guard self.validateWalkLocationSample(location) else { return }
                self.updateMovementState(with: location)
            }
            withAnimation() {
                self.location = location
            }
            self.nearbyTick()
            self.handleAutoPointRecord(with: location)
            self.compactMapMotionArtifacts()
            self.persistActiveWalkSession()
            self.handleAutoEndIfNeeded()
        }
    }

    func setRegion(_ location : CLLocation?, distance: Double = 2000){
        guard let coordinate=location?.coordinate else {return}
        withAnimation(.easeInOut(duration: 0.3)){
            cameraPosition = MapCameraPosition.camera(.init(centerCoordinate: coordinate, distance: distance))
        }
    }
    func setRegion(_ coordination : CLLocationCoordinate2D?, distance: Double = 2000){
        guard let coordinate=coordination else {return}
        withAnimation(.easeInOut(duration: 0.3)){
            cameraPosition = MapCameraPosition.camera(.init(centerCoordinate: coordinate, distance: distance))
        }
    }
    private func seeCurrentLocation(){
        guard let location = self.location else {
            cameraPosition = MapCameraPosition.userLocation(followsHeading: true, fallback: .automatic)
            return }
        cameraPosition = MapCameraPosition.userLocation(followsHeading: true, fallback: MapCameraPosition.camera(.init(centerCoordinate: location.coordinate, distance: 2000)))
    }

}
//MARK: - 클러스터링 관련 내용
extension MapViewModel {
    func updateAnnotations(cameraDistance: Double){
        let safeDistance = max(120.0, cameraDistance)
        let previousCount = centerLocations.count
        currentCameraDistance = safeDistance
        let nextClusters = cluster(distance: safeDistance)
        centerLocations = nextClusters

        let nextCount = nextClusters.count
        if nextCount > previousCount {
            clusterMotionTransition = .decompose
            clusterMotionToken += 1
        } else if nextCount < previousCount {
            clusterMotionTransition = .merge
            clusterMotionToken += 1
        } else {
            clusterMotionTransition = .none
        }
    }
    private func hotspots() async { // 핫스팟 로직 고민해보기

    }
    private struct ClusterBucketKey: Hashable {
        let x: Int
        let y: Int
    }

    private func clusterCellSizeMeters(for distance: Double) -> Double {
        let raw = distance * clusterCellDistanceRatio
        return min(clusterCellMaxMeters, max(clusterCellMinMeters, raw))
    }

    private func initialClusterByPolygon() -> [Cluster] {
        return self.polygonList.compactMap { polygon in
            guard let mapPolygon = polygon.polygon else { return nil }
            return Cluster(center: mapPolygon.coordinate, id: polygon.id)
        }
    }
    private func cluster(distance: Double) -> [Cluster] {
        let startCluster = initialClusterByPolygon()
        let result = calculateDistance(from: startCluster, threshold: distance)
        return result
    }
    
    private func calculateDistance(from clusters: [Cluster], threshold: Double) -> [Cluster] {
        guard clusters.count > 1 else { return clusters }

        let referenceLatitude = clusters.map(\.center.latitude).reduce(0.0, +) / Double(clusters.count)
        let cellMeters = clusterCellSizeMeters(for: threshold)
        let metersPerMapPoint = MKMetersPerMapPointAtLatitude(referenceLatitude)
        let cellMapPoints = max(1.0, cellMeters / max(0.0001, metersPerMapPoint))

        var buckets: [ClusterBucketKey: Cluster] = [:]
        buckets.reserveCapacity(clusters.count)

        for cluster in clusters {
            let point = MKMapPoint(cluster.center)
            let key = ClusterBucketKey(
                x: Int(floor(point.x / cellMapPoints)),
                y: Int(floor(point.y / cellMapPoints))
            )

            if var existing = buckets[key] {
                existing.updateCenter(with: cluster)
                buckets[key] = existing
            } else {
                buckets[key] = cluster
            }
        }

        return buckets.values.sorted { lhs, rhs in
            if lhs.sumLocs.count != rhs.sumLocs.count {
                return lhs.sumLocs.count > rhs.sumLocs.count
            }
            if lhs.center.latitude != rhs.center.latitude {
                return lhs.center.latitude < rhs.center.latitude
            }
            return lhs.center.longitude < rhs.center.longitude
        }
    }
}

// MARK: - WatchConnectivity
extension MapViewModel {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("watch activation failed: \(error.localizedDescription)")
            return
        }
        self.syncWatchContext(force: true)
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    func sessionReachabilityDidChange(_ session: WCSession) {
        self.syncWatchContext(force: true)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String : Any],
        replyHandler: @escaping ([String : Any]) -> Void
    ) {
        let ack = self.handleWatchPayload(message) ?? [
            "version": WatchContract.version,
            "type": WatchContract.ackType,
            "status": "ignored",
            "last_sync_at": Date().timeIntervalSince1970
        ]
        replyHandler(ack)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        self.handleWatchPayload(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        self.handleWatchPayload(userInfo)
    }
}
