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
    private let watchSession = WCSession.isSupported() ? WCSession.default : nil
    private var processedWatchActionIds: Set<String> = []
    private var processedWatchActionOrder: [String] = []
    private let maxProcessedWatchActions = 500
    private var lastWatchContextSyncAt: Date = .distantPast
    private let processedWatchActionStorageKey = "watch.processedActionIds"
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
        self.setupWatchConnectivity()
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
                    _ = savePolygon(polygon: self.polygon)
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
        let points = self.polygonList.flatMap { $0.locations }
        self.heatmapCells = HeatmapEngine.aggregate(points: points, now: now, precision: 7)
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
        let actionId = payload["action_id"] as? String ?? UUID().uuidString
        if shouldProcessWatchAction(actionId: actionId) == false {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch action {
            case "startWalk":
                if self.isWalking == false { self.endWalk() }
            case "addPoint":
                if self.isWalking {
                    self.addLocation()
                    self.syncWatchContext(force: true)
                }
            case "endWalk":
                if self.isWalking { self.endWalk() }
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
