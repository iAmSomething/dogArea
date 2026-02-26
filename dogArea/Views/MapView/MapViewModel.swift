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
import CoreData
import Combine
import WatchConnectivity
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif
class MapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate, CoreDataProtocol, WCSessionDelegate {
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
    @Published var watchSyncStatusText: String = "워치 동기화 대기"
    @Published var latestWatchActionText: String = ""
    @Published var walkStatusMessage: String? = nil
    @Published var runtimeGuardStatusText: String = ""
    @Published var syncOutboxPendingCount: Int = 0
    @Published var syncOutboxPermanentFailureCount: Int = 0
    @Published var syncOutboxLastErrorCodeText: String = ""
    @Published var syncRecoveryToastMessage: String? = nil
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
    private let processedWatchActionStorageKey = "watch.processedActionIds"
    private let activeWalkSessionStorageKey = "walk.activeSession.v1"
    private let heatmapEnabledKey = "heatmap.enabled"
    private let locationSharingKey = "nearby.locationSharingEnabled"
    private let nearbyHotspotEnabledKey = "nearby.hotspotEnabled"
    private let nearbyPresenceUserIdKey = "nearby.presenceUserId"
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

    private enum WatchIncomingAction: String {
        case startWalk
        case addPoint
        case endWalk
        case syncState
    }

    private enum PointAppendSource {
        case manual
        case auto
        case watch
    }

    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.allowsBackgroundLocationUpdates = true
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest // 정확도 설정
        self.locationManager.requestWhenInUseAuthorization() // 권한 요청
        self.locationManager.startUpdatingLocation() // 위치 업데이트 시작
        self.reloadPolygonState(restoreLatestPolygon: true)
        self.loadProcessedWatchActions()

        let storedHeatmapEnabled = UserDefaults.standard.object(forKey: heatmapEnabledKey) as? Bool ?? true
        let storedNearbyHotspotEnabled = UserDefaults.standard.object(forKey: nearbyHotspotEnabledKey) as? Bool ?? true
        let storedLocationSharingEnabled = UserDefaults.standard.bool(forKey: locationSharingKey)

        self.heatmapEnabled = featureFlags.isEnabled(.heatmapV1) ? storedHeatmapEnabled : false
        let nearbyFeatureOn = featureFlags.isEnabled(.nearbyHotspotV1)
        self.nearbyHotspotEnabled = nearbyFeatureOn ? storedNearbyHotspotEnabled : false
        self.locationSharingEnabled = nearbyFeatureOn ? storedLocationSharingEnabled : false
        self.walkStartCountdownEnabled = UserdefaultSetting.shared.walkStartCountdownEnabled()
        self.walkAutoEndPolicyEnabled = true
        self.walkPointRecordMode = WalkPointRecordMode(
            rawValue: UserdefaultSetting.shared.walkPointRecordModeRawValue()
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
    }

    deinit {
        timer?.invalidate()
        nearbyTickTimer?.invalidate()
        syncFlushTask?.cancel()
        lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func applyPolygonList(_ polygons: [Polygon], restoreLatestPolygon: Bool = false) {
        self.polygonList = polygons
        if restoreLatestPolygon {
            self.polygon = polygons.last ?? Polygon(walkingTime: 0.0, walkingArea: 0.0)
        }
        self.refreshHeatmap()
    }

    private func reloadPolygonState(restoreLatestPolygon: Bool = false) {
        let latest = self.fetchPolygons()
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
                let updated = deletePolygon(id: self.polygon.id)
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
                    polygon.makePolygon(walkArea: calculateArea(), walkTime: self.time, img: img)
                    let completedPolygon = self.polygon
                    let updated = savePolygon(polygon: completedPolygon)
                    let saved = updated.contains(where: { $0.id == completedPolygon.id })
                    metricTracker.track(
                        saved ? .walkSaveSuccess : .walkSaveFailed,
                        userKey: currentMetricUserId(),
                        featureKey: .heatmapV1,
                        payload: ["pointCount": "\(completedPolygon.locations.count)"]
                    )
                    if saved {
                        enqueueSyncOutbox(for: completedPolygon, hasImage: img != nil)
                        let endedAt = (endedAtOverride ?? Date()).timeIntervalSince1970
                        WalkSessionMetadataStore.shared.set(
                            sessionId: completedPolygon.id,
                            reason: .init(rawValue: reason.rawValue) ?? .manual,
                            endedAt: endedAt
                        )
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
        UserdefaultSetting.shared.setWalkStartCountdownEnabled(walkStartCountdownEnabled)
    }

    func toggleWalkPointRecordMode() {
        walkPointRecordMode = walkPointRecordMode == .manual ? .auto : .manual
        UserdefaultSetting.shared.setWalkPointRecordModeRawValue(walkPointRecordMode.rawValue)
        resetAutoPointRecordState()
    }

    var isAutoPointRecordMode: Bool {
        walkPointRecordMode == .auto
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
        syncOutbox.enqueueWalkStages(
            walkSessionId: polygon.id,
            userId: currentMetricUserId(),
            pointCount: polygon.locations.count,
            durationSec: polygon.walkingTime,
            areaM2: polygon.walkingArea,
            hasImage: hasImage,
            createdAt: polygon.createdAt
        )
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
        let lastMovementAt = snapshotLastMovementTime(snapshot)
        let inactivity = now.timeIntervalSince(lastMovementAt)
        if inactivity >= inactivityFinalizeInterval {
            autoFinalizeRecoverableSession(snapshot, now: now, lastMovementAt: lastMovementAt)
            return
        }
        pendingRecoverableSession = snapshot
        hasRecoverableWalkSession = true
        recoverableWalkSummaryText = "미종료 산책 \(Int(snapshot.elapsedTime))초 · 포인트 \(snapshot.points.count)개"
        if inactivity < restCandidateInterval {
            resumeRecoverableWalkSession(autoRecovered: true)
        }
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

    private func autoFinalizeRecoverableSession(
        _ snapshot: ActiveWalkSessionSnapshot,
        now: Date,
        lastMovementAt: Date
    ) {
        let restoredPoints = snapshot.points.map {
            Location(
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                id: UUID(),
                createdAt: $0.createdAt
            )
        }
        guard restoredPoints.count > 2 else {
            clearActiveWalkSession()
            walkStatusMessage = "15분 무이동으로 미종료 산책 임시기록을 폐기했습니다."
            return
        }
        let endedAt = min(now.timeIntervalSince1970, lastMovementAt.timeIntervalSince1970 + inactivityFinalizeInterval)
        let walkTime = max(0, endedAt - snapshot.startedAt)
        let restoredSessionId = snapshot.sessionId.flatMap(UUID.init(uuidString:))
        let completed = Polygon(
            locations: restoredPoints,
            createdAt: snapshot.startedAt,
            id: restoredSessionId ?? UUID(),
            walkingTime: walkTime,
            walkingArea: 0.0,
            imgData: nil
        )
        var finalized = completed
        finalized.makePolygon(walkArea: calculateArea(points: restoredPoints), walkTime: walkTime)
        let updated = savePolygon(polygon: finalized)
        if updated.contains(where: { $0.id == finalized.id }) {
            WalkSessionMetadataStore.shared.set(
                sessionId: finalized.id,
                reason: .autoInactive,
                endedAt: endedAt
            )
            enqueueSyncOutbox(for: finalized, hasImage: finalized.binaryImage != nil)
            walkStatusMessage = "15분 무이동으로 이전 산책을 자동 종료했습니다."
        } else {
            walkStatusMessage = "이전 산책 자동 종료 저장에 실패했습니다."
        }
        applyPolygonList(updated)
        clearActiveWalkSession()
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

        polygon = Polygon(locations: restoredPoints, walkingTime: snapshot.elapsedTime, walkingArea: 0.0)
        if let sessionId = snapshot.sessionId, let restoredId = UUID(uuidString: sessionId) {
            polygon.id = restoredId
        }
        time = snapshot.elapsedTime
        startTime = Date().addingTimeInterval(-snapshot.elapsedTime)
        if restoredPoints.count > 2 {
            makePolygon()
        }

        if let selectedPetId = snapshot.selectedPetId {
            UserdefaultSetting.shared.setSelectedPetId(selectedPetId)
        }
        reloadSelectedPetContext()
        currentWalkingPetName = snapshot.currentWalkingPetName
        walkPointRecordMode = WalkPointRecordMode(rawValue: snapshot.pointRecordMode) ?? .manual
        UserdefaultSetting.shared.setWalkPointRecordModeRawValue(walkPointRecordMode.rawValue)

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
        pendingRecoverableSession = nil
        hasRecoverableWalkSession = false
        recoverableWalkSummaryText = ""
        clearActiveWalkSession()
    }

    func finalizeRecoverableWalkSessionNow() {
        guard let snapshot = pendingRecoverableSession else {
            clearActiveWalkSession()
            return
        }
        let restoredPoints = snapshot.points.map {
            Location(
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                id: UUID(),
                createdAt: $0.createdAt
            )
        }
        guard restoredPoints.count > 2 else {
            clearActiveWalkSession()
            walkStatusMessage = "미종료 산책 임시기록을 폐기했습니다."
            return
        }
        let nowTs = Date().timeIntervalSince1970
        let walkTime = max(0, nowTs - snapshot.startedAt)
        let restoredSessionId = snapshot.sessionId.flatMap(UUID.init(uuidString:))
        let completed = Polygon(
            locations: restoredPoints,
            createdAt: snapshot.startedAt,
            id: restoredSessionId ?? UUID(),
            walkingTime: walkTime,
            walkingArea: 0.0,
            imgData: nil
        )
        var finalized = completed
        finalized.makePolygon(walkArea: calculateArea(points: restoredPoints), walkTime: walkTime)
        let updated = savePolygon(polygon: finalized)
        if updated.contains(where: { $0.id == finalized.id }) {
            WalkSessionMetadataStore.shared.set(
                sessionId: finalized.id,
                reason: .manual,
                endedAt: nowTs
            )
            enqueueSyncOutbox(for: finalized, hasImage: finalized.binaryImage != nil)
            walkStatusMessage = "미종료 산책을 지금 종료로 저장했습니다."
        } else {
            walkStatusMessage = "미종료 산책 종료 저장에 실패했습니다."
        }
        applyPolygonList(updated)
        clearActiveWalkSession()
    }

    private func decodeActiveWalkSession() -> ActiveWalkSessionSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: activeWalkSessionStorageKey) else {
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
            UserDefaults.standard.set(data, forKey: activeWalkSessionStorageKey)
            lastSnapshotPersistAt = now
        }
    }

    private func clearActiveWalkSession() {
        UserDefaults.standard.removeObject(forKey: activeWalkSessionStorageKey)
        pendingRecoverableSession = nil
        hasRecoverableWalkSession = false
        recoverableWalkSummaryText = ""
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
            } else {
                discardCurrentWalk()
                walkStatusMessage = "15분 무이동으로 산책 임시기록을 폐기했습니다."
            }
            return
        }

        if inactivity >= inactivityWarningInterval, didNotifyInactivityWarning == false {
            didNotifyInactivityWarning = true
            walkStatusMessage = "12분 무이동: 3분 후 자동 종료 예정입니다."
            return
        }

        if inactivity >= restCandidateInterval, didNotifyRestCandidate == false {
            didNotifyRestCandidate = true
            walkStatusMessage = "5분 무이동: 휴식 상태로 감지했습니다."
        }
    }

    private func setupLifecycleObservers() {
        #if canImport(UIKit)
        let center = NotificationCenter.default
        let didBecomeActive = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flushSyncOutboxIfNeeded(force: true)
            self?.syncVisibilitySettingIfNeeded()
        }
        let willResign = center.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.persistActiveWalkSession(force: true)
        }
        let willTerminate = center.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.persistActiveWalkSession(force: true)
        }
        let petContextChanged = center.addObserver(
            forName: UserdefaultSetting.selectedPetDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadSelectedPetContext()
        }
        lifecycleObservers = [didBecomeActive, willResign, willTerminate, petContextChanged]
        #endif
    }

    private func appendWalkPoint(from location: CLLocation, recordedAt: Date, source: PointAppendSource) {
        polygon.addPoint(.init(coordinate: location.coordinate))
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
        let updated = deletePolygon(id: id)
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
        let value = UserDefaults.standard.integer(forKey: key)
        return value > 0 ? value : defaultValue
    }

    private func lodDoubleValue(key: String, defaultValue: Double) -> Double {
        let value = UserDefaults.standard.double(forKey: key)
        return value > 0 ? value : defaultValue
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

    func heatmapColor(for score: Double) -> Color {
        switch HeatmapCellDTO.intensityLevel(for: score) {
        case 0: return Color.appGreen
        case 1: return Color.appYellowPale
        case 2: return Color.appYellow
        case 3: return Color.appPeach
        default: return Color.appRed
        }
    }

    func heatmapOpacity(for score: Double) -> Double {
        switch HeatmapCellDTO.intensityLevel(for: score) {
        case 0: return 0.25
        case 1: return 0.35
        case 2: return 0.45
        case 3: return 0.55
        default: return 0.65
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
        UserDefaults.standard.set(self.heatmapEnabled, forKey: heatmapEnabledKey)
        if self.heatmapEnabled {
            refreshHeatmap()
        } else {
            self.heatmapCells = []
        }
    }

    func toggleLocationSharing() {
        guard isNearbyHotspotFeatureAvailable else {
            self.locationSharingEnabled = false
            UserDefaults.standard.set(false, forKey: locationSharingKey)
            self.syncVisibilitySettingIfNeeded()
            return
        }
        self.locationSharingEnabled.toggle()
        UserDefaults.standard.set(self.locationSharingEnabled, forKey: locationSharingKey)
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
            UserDefaults.standard.set(false, forKey: nearbyHotspotEnabledKey)
            return
        }
        self.nearbyHotspotEnabled.toggle()
        UserDefaults.standard.set(self.nearbyHotspotEnabled, forKey: nearbyHotspotEnabledKey)
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

    private func fetchNearbyHotspots(center: CLLocationCoordinate2D) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let hotspots = try await nearbyService.getHotspots(
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
        let heatmapPreference = UserDefaults.standard.object(forKey: heatmapEnabledKey) as? Bool ?? true
        let nearbyPreference = UserDefaults.standard.object(forKey: nearbyHotspotEnabledKey) as? Bool ?? true
        let sharingPreference = UserDefaults.standard.bool(forKey: locationSharingKey)

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
            UserDefaults.standard.set(false, forKey: locationSharingKey)
            self.syncVisibilitySettingIfNeeded()
        }
    }

    private func currentPresenceUserId() -> String? {
        if let existing = UserDefaults.standard.string(forKey: nearbyPresenceUserIdKey) {
            return existing
        }
        guard let raw = UserdefaultSetting.shared.getValue()?.id,
              raw.isEmpty == false else {
            return nil
        }
        let stable = raw.stableUUIDString
        UserDefaults.standard.set(stable, forKey: nearbyPresenceUserIdKey)
        return stable
    }

    private func currentMetricUserId() -> String? {
        guard let raw = UserdefaultSetting.shared.getValue()?.id, raw.isEmpty == false else {
            return nil
        }
        return raw
    }

    func reloadSelectedPetContext() {
        let userInfo = UserdefaultSetting.shared.getValue()
        self.availablePets = userInfo?.pet ?? []
        let selectedPet = UserdefaultSetting.shared.selectedPet(from: userInfo)
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
        guard let userInfo = UserdefaultSetting.shared.getValue(), userInfo.pet.isEmpty == false else {
            reloadSelectedPetContext()
            return
        }
        if let suggested = UserdefaultSetting.shared.suggestedPetForWalkStart(from: userInfo),
           suggested.petId != selectedPetId {
            UserdefaultSetting.shared.setSelectedPetId(suggested.petId, source: "walk_start_suggestion")
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
        UserdefaultSetting.shared.setSelectedPetId(nextPet.petId, source: "walk_start_switcher")
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
            "isWalking": self.isWalking,
            "time": self.time,
            "area": self.polygon.walkingArea,
            "last_sync_at": now.timeIntervalSince1970
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
        let stored = UserDefaults.standard.stringArray(forKey: processedWatchActionStorageKey) ?? []
        self.processedWatchActionOrder = stored
        self.processedWatchActionIds = Set(stored)
    }

    private func persistProcessedWatchActions() {
        UserDefaults.standard.set(self.processedWatchActionOrder, forKey: processedWatchActionStorageKey)
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

    private func handleWatchPayload(_ payload: [String: Any]) {
        guard let action = parseWatchAction(from: payload) else { return }
        let actionName = action.rawValue
        latestWatchActionText = "워치 \(actionName) 수신 \(Self.statusTimeString(from: Date()))"
        metricTracker.track(
            .watchActionReceived,
            userKey: currentMetricUserId(),
            payload: ["action": actionName]
        )
        let actionId: String = {
            if let id = payload["action_id"] as? String, id.isEmpty == false {
                return id
            }
            if let sentAt = payload["sent_at"] as? TimeInterval {
                return "\(actionName):\(Int(sentAt * 1000.0))"
            }
            return UUID().uuidString
        }()
        if shouldProcessWatchAction(actionId: actionId) == false {
            metricTracker.track(
                .watchActionDuplicate,
                userKey: currentMetricUserId(),
                payload: ["action": actionName]
            )
            return
        }
        metricTracker.track(
            .watchActionProcessed,
            userKey: currentMetricUserId(),
            payload: ["action": actionName]
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyWatchAction(action)
        }
    }

    private func parseWatchAction(from payload: [String: Any]) -> WatchIncomingAction? {
        guard let rawAction = payload["action"] as? String else { return nil }
        return WatchIncomingAction(rawValue: rawAction)
    }

    private func applyWatchAction(_ action: WatchIncomingAction) {
        switch action {
        case .startWalk:
            if self.isWalking == false {
                self.startWalkNow()
                self.latestWatchActionText = "워치 시작 반영 \(Self.statusTimeString(from: Date()))"
                self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action.rawValue])
            } else {
                self.syncWatchContext(force: true)
            }
        case .addPoint:
            if self.isWalking {
                if let location = self.location {
                    self.appendWalkPoint(from: location, recordedAt: Date(), source: .watch)
                    self.syncWatchContext(force: true)
                    self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action.rawValue])
                }
            } else {
                self.syncWatchContext(force: true)
            }
        case .endWalk:
            if self.isWalking {
                self.endWalk()
                self.latestWatchActionText = "워치 종료 반영 \(Self.statusTimeString(from: Date()))"
                self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action.rawValue])
            } else {
                self.syncWatchContext(force: true)
            }
        case .syncState:
            self.latestWatchActionText = "워치 상태 재동기화 \(Self.statusTimeString(from: Date()))"
            self.syncWatchContext(force: true)
        }
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
        currentCameraDistance = safeDistance
        centerLocations = cluster(distance: safeDistance)
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

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        self.handleWatchPayload(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        self.handleWatchPayload(userInfo)
    }
}

private extension String {
    var stableUUIDString: String {
        let digest = SHA256.hash(data: Data(self.utf8))
        let bytes = Array(digest.prefix(16))
        let uuid = UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            )
        )
        return uuid.uuidString.lowercased()
    }
}

private struct NearbyPresenceService {
    private enum ServiceError: Error {
        case notConfigured
        case invalidURL
        case badResponse
    }

    private struct ResponseHotspotDTO: Decodable {
        let geohash7: String
        let count: Int
        let intensity: Double
        let center_lat: Double
        let center_lng: Double
    }

    private struct HotspotEnvelope: Decodable {
        let hotspots: [ResponseHotspotDTO]
    }

    private func endpointURL() throws -> URL {
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["SUPABASE_URL"], raw.isEmpty == false else {
            throw ServiceError.notConfigured
        }
        guard let url = URL(string: raw + "/functions/v1/nearby-presence") else {
            throw ServiceError.invalidURL
        }
        return url
    }

    private func bearerToken() -> String {
        ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    }

    private func requestBody(_ payload: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: payload)
    }

    private func post(payload: [String: Any]) async throws -> Data {
        let url = try endpointURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = bearerToken()
        if token.isEmpty == false {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try requestBody(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let code = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(code) else {
            throw ServiceError.badResponse
        }
        return data
    }

    func setVisibility(userId: String, enabled: Bool) async throws {
        _ = try await post(payload: [
            "action": "set_visibility",
            "userId": userId,
            "enabled": enabled
        ])
    }

    func upsertPresence(userId: String, latitude: Double, longitude: Double) async throws {
        _ = try await post(payload: [
            "action": "upsert_presence",
            "userId": userId,
            "lat": latitude,
            "lng": longitude
        ])
    }

    func getHotspots(
        centerLatitude: Double,
        centerLongitude: Double,
        radiusKm: Double
    ) async throws -> [NearbyHotspotDTO] {
        let data = try await post(payload: [
            "action": "get_hotspots",
            "centerLat": centerLatitude,
            "centerLng": centerLongitude,
            "radiusKm": radiusKm
        ])
        let decoded = try JSONDecoder().decode(HotspotEnvelope.self, from: data)
        return decoded.hotspots.map {
            NearbyHotspotDTO(
                geohash: $0.geohash7,
                count: $0.count,
                intensity: max(0.0, min(1.0, $0.intensity)),
                centerCoordinate: CLLocationCoordinate2D(latitude: $0.center_lat, longitude: $0.center_lng)
            )
        }
    }
}
