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
class MapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate, CoreDataProtocol{
    @Environment(\.managedObjectContext) private var viewContext
    
    private let locationManager = CLLocationManager()
    private var timer: Timer? = nil
    @Published var time: TimeInterval = 0.0
    @Published var startTime = Date()
    @Published var location: CLLocation?
    @Published var polygon : Polygon = Polygon(walkingTime: 0.0, walkingArea: 0.0)
    @Published var polygonList: [Polygon] = []
    @Published var isWalking: Bool = false{
        didSet {
            //산책 시작 버튼 눌렀을 때
            if self.isWalking {
                self.showOnlyOne = true
            }
        }
    }
    @Published var camera: MapCamera = .init(.init())
    @Published var cameraPosition = MapCameraPosition.userLocation(followsHeading: false,fallback: .automatic)
    @Published var selectedMarker: Location? = nil
    @Published var showOnlyOne: Bool = true
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.allowsBackgroundLocationUpdates = true
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest // 정확도 설정
        self.locationManager.requestWhenInUseAuthorization() // 권한 요청
        self.locationManager.startUpdatingLocation() // 위치 업데이트 시작
        self.polygonList = self.fetchPolygons()
        self.polygon = lastPolygon() ?? Polygon(walkingTime: 0.0, walkingArea: 0.0)
    }
    func fetchPolygonList() {
        self.polygonList = self.fetchPolygons()
    }
    private func lastPolygon() -> Polygon? {
        return polygonList.last
    }
    func addLocation(){
        if let location = self.location{
            polygon.addPoint(.init(coordinate: location.coordinate))
        }
    }
    func removeLocation(_ locationID : UUID){
        if let first = polygon.locations.firstIndex(where:{ $0.id == locationID}){
            polygon.removeAt(locationID)
            if polygon.locations.count<3 {
                self.polygonList = deletePolygon(id: self.polygon.id)
                polygonList.removeAll(where: {$0.id == self.polygon.id})
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
                    self.polygonList = savePolygon(polygon: self.polygon)
                }
            time = 0.0
        }
        else {
            setTrackingMode()
            timerSet()
            polygon.clear()
        }
        withAnimation{
            isWalking.toggle()
        }
    }
    func setTrackingMode() {
        if let location = self.location{
            withAnimation(.easeInOut(duration: 0.3)){
                cameraPosition=MapCameraPosition.userLocation(followsHeading: true,fallback: .automatic)
            }
        }
    }

}
//MARK: - 넓이와 시간로직
extension MapViewModel {
    func timerSet() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            self.time += t.timeInterval
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
        if area > 100000.0 {
            str = String(format: "%.2f" , area/1000000) + "k㎡"
        }
        if isPyong {
            str = String(format: "%.1f" , area/3.3) + "평"
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
        print(manager.location?.description)
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            withAnimation{
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
        cameraPosition = MapCameraPosition.userLocation(followsHeading: true, fallback: cameraPosition)
    }
}
extension MapViewModel {
    func mapImg(view: some View) -> UIImage {
        view.asUiImage()
    }
}
