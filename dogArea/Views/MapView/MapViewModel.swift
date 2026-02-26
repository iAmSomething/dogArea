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
class MapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate, CoreDataProtocol, WCSessionDelegate {
    @Environment(\.managedObjectContext) private var viewContext
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
    @Published var camera: MapCamera = .init(.init())
    @Published var cameraPosition = MapCameraPosition.userLocation(followsHeading: false,fallback: .automatic)
    @Published var selectedMarker: Location? = nil
    @Published var showOnlyOne: Bool = true
    @Published var heatmapEnabled: Bool = true
    @Published var heatmapCells: [HeatmapCellDTO] = []
    @Published var nearbyHotspotEnabled: Bool = true
    @Published var locationSharingEnabled: Bool = false
    @Published var nearbyHotspots: [NearbyHotspotDTO] = []
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
    private let heatmapEnabledKey = "heatmap.enabled"
    private let locationSharingKey = "nearby.locationSharingEnabled"
    private let nearbyHotspotEnabledKey = "nearby.hotspotEnabled"
    private let nearbyPresenceUserIdKey = "nearby.presenceUserId"
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.allowsBackgroundLocationUpdates = true
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest // 정확도 설정
        self.locationManager.requestWhenInUseAuthorization() // 권한 요청
        self.locationManager.startUpdatingLocation() // 위치 업데이트 시작
        self.polygonList = self.fetchPolygons()
        self.polygon = lastPolygon() ?? Polygon(walkingTime: 0.0, walkingArea: 0.0)
        self.refreshHeatmap()
        self.loadProcessedWatchActions()

        let storedHeatmapEnabled = UserDefaults.standard.object(forKey: heatmapEnabledKey) as? Bool ?? true
        let storedNearbyHotspotEnabled = UserDefaults.standard.object(forKey: nearbyHotspotEnabledKey) as? Bool ?? true
        let storedLocationSharingEnabled = UserDefaults.standard.bool(forKey: locationSharingKey)

        self.heatmapEnabled = featureFlags.isEnabled(.heatmapV1) ? storedHeatmapEnabled : false
        let nearbyFeatureOn = featureFlags.isEnabled(.nearbyHotspotV1)
        self.nearbyHotspotEnabled = nearbyFeatureOn ? storedNearbyHotspotEnabled : false
        self.locationSharingEnabled = nearbyFeatureOn ? storedLocationSharingEnabled : false
        self.setupWatchConnectivity()
        self.startNearbyTicker()
        self.syncVisibilitySettingIfNeeded()
        self.refreshFeatureFlagsFromRemote()
    }

    deinit {
        timer?.invalidate()
        nearbyTickTimer?.invalidate()
    }
    func fetchPolygonList() {
        self.polygonList = self.fetchPolygons()
        self.refreshHeatmap()
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
    private func lastPolygon() -> Polygon? {
        return polygonList.last
    }
    func addLocation(){
        if let location = self.location{
            polygon.addPoint(.init(coordinate: location.coordinate))
            self.syncWatchContext(force: true)
        }
    }
    func removeLocation(_ locationID : UUID){
        if polygon.locations.firstIndex(where:{ $0.id == locationID}) != nil {
            polygon.removeAt(locationID)
            if polygon.locations.count<3 {
                _ = deletePolygon(id: self.polygon.id)
                self.polygonList = self.fetchPolygons()
                self.refreshHeatmap()
            }
        }
    }
    func makePolygon() {
        if self.polygon.locations.count > 2{
            polygon.makePolygon(walkArea: calculateArea(), walkTime: self.time)
        }
    }
    func endWalk(img: UIImage? = nil){
        if isWalking {
                if self.polygon.locations.count > 2{
                    polygon.makePolygon(walkArea: calculateArea(), walkTime: self.time, img: img)
                    let saved = savePolygon(polygon: self.polygon).isEmpty == false
                    metricTracker.track(
                        saved ? .walkSaveSuccess : .walkSaveFailed,
                        userKey: currentMetricUserId(),
                        featureKey: .heatmapV1,
                        payload: ["pointCount": "\(self.polygon.locations.count)"]
                    )
                    self.polygonList = self.fetchPolygons()
                    self.refreshHeatmap()
                }
            time = 0.0
        }
        else {
            setTrackingMode()
            timerSet()
            polygon.clear()
        }
        withAnimation{ [weak self] in
            self?.isWalking.toggle()
        }
        self.syncWatchContext(force: true)
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
        if !isWalking {
            guard let lastTime = self.polygon.locations.last?.createdAt else {return}
            let duration = Date().timeIntervalSince1970 - lastTime
            if duration > 1800 {
                self.endWalk()
            }
        }
    }

    func deletePolygonAndRefresh(_ id: UUID) {
        _ = deletePolygon(id: id)
        self.fetchPolygonList()
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

    var isNearbyHotspotFeatureAvailable: Bool {
        featureFlags.isEnabled(.nearbyHotspotV1)
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
        let heatmapPreference = UserDefaults.standard.object(forKey: heatmapEnabledKey) as? Bool ?? true
        let nearbyPreference = UserDefaults.standard.object(forKey: nearbyHotspotEnabledKey) as? Bool ?? true
        let sharingPreference = UserDefaults.standard.bool(forKey: locationSharingKey)

        self.heatmapEnabled = heatmapAllowed ? heatmapPreference : false
        self.nearbyHotspotEnabled = nearbyAllowed ? nearbyPreference : false
        self.locationSharingEnabled = nearbyAllowed ? sharingPreference : false

        if heatmapAllowed {
            self.refreshHeatmap()
        } else {
            self.heatmapCells = []
        }

        if nearbyAllowed == false {
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
        } catch {
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
        guard let action = payload["action"] as? String else { return }
        metricTracker.track(
            .watchActionReceived,
            userKey: currentMetricUserId(),
            payload: ["action": action]
        )
        let actionId = payload["action_id"] as? String ?? UUID().uuidString
        if shouldProcessWatchAction(actionId: actionId) == false {
            metricTracker.track(
                .watchActionDuplicate,
                userKey: currentMetricUserId(),
                payload: ["action": action]
            )
            return
        }
        metricTracker.track(
            .watchActionProcessed,
            userKey: currentMetricUserId(),
            payload: ["action": action]
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch action {
            case "startWalk":
                if self.isWalking == false {
                    self.endWalk()
                    self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action])
                }
            case "addPoint":
                if self.isWalking {
                    self.addLocation()
                    self.syncWatchContext(force: true)
                    self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action])
                }
            case "endWalk":
                if self.isWalking {
                    self.endWalk()
                    self.metricTracker.track(.watchActionApplied, userKey: self.currentMetricUserId(), payload: ["action": action])
                }
            default:
                break
            }
        }
    }

}
//MARK: - 넓이와 시간로직
extension MapViewModel {
    func timerSet() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {[weak self] t in
            guard let self = self else {return}
            self.time += t.timeInterval
            self.syncWatchContext()
            if self.time > 3600 {
                self.forceQuit()
            }
        }
    }
    func timerStop() {
        timer?.invalidate()
        timer = nil
    }
    func calculateArea() -> Double {
         let points = self.polygon.locations
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
        var area = 0.0
        if areaSize == nil {
            area = calculateArea()
        } else {
            area = areaSize!
        }
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
        case .notDetermined, .restricted, .denied:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            print("")
            
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
            withAnimation(){
                self?.location = location
            }
            self?.nearbyTick()
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
        Task { @MainActor in
            do {
                centerLocations = await cluster(distance: cameraDistance)
            }
        }
    }
    private func hotspots() async { // 핫스팟 로직 고민해보기

    }
    private func initialClusterByPolygon() async -> [Cluster] {
        return self.polygonList
            .filter{!$0.polygon.isNil}
            .map{Cluster(center: $0.polygon!.coordinate, id: $0.id)}
    }
    private func cluster(distance: Double) async -> [Cluster] {
        let startCluster = await initialClusterByPolygon()
        let result = await calculateDistance(from: startCluster, threshold: distance)
        return result
    }
    
    private func calculateDistance(from clusters: [Cluster], threshold: Double) async -> [Cluster] {
        var tempClusters = clusters
        var i = 0, j = 0
        while(i < tempClusters.count) {
            j = i + 1
            while(j < tempClusters.count) {
                let distance = tempClusters[i].center.distance(to: tempClusters[j].center) * 5000000
                if distance < threshold {
                    tempClusters[i].updateCenter(with: tempClusters[j])
                    tempClusters.remove(at: j)
                    j -= 1
                }
                j += 1
            }
            i += 1
        }
        return tempClusters
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
