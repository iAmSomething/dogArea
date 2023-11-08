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
  @Published var polygon : Polygon = .init()
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
    self.polygon = lastPolygon() ?? Polygon.init()
  }
  
  func addLocation(){
    if let location = self.location{
      polygon.addPoint(.init(coordinate: location.coordinate))
    }
  }
  
  func removeLocation(_ locationID : UUID){
    if let _ = polygon.locations.firstIndex(where:{ $0.id == locationID}){
      polygon.removeAt(locationID)
      if polygon.locations.count<3 {
        self.polygonList = deletePolygon(id: polygon.id)
        polygonList.removeAll(where: {$0.id == polygon.id})
      }
    }
  }
  func fetchPolygonList() {
    self.polygonList = self.fetchPolygons()
  }
  
  func endWalk(){
    if isWalking {
      timer?.invalidate()
      timer = nil
      time = 0.0
      polygon.makePolygon()
      if polygon.locations.count > 2{
        self.polygonList = savePolygon(polygon: self.polygon)
      }
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
  func timerSet() {
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
      self.time += t.timeInterval
#if DEBUG
      //      if Int(self.time) % 10 == 0 {
      //        self.addLocation()
      //      }
#endif
    }
  }
  func calculateArea() -> Double {
      let points = self.polygon.locations
      guard points.count >= 3 else {
          // At least 3 points are needed.
          return 0
      }
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
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    DispatchQueue.main.async { [weak self] in
      self?.location = location
    }
  }
  func setTrackingMode() {
    if let location = self.location{
      withAnimation(.easeInOut(duration: 0.3)){
        cameraPosition=MapCameraPosition.userLocation(followsHeading: true,fallback: .automatic)
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
  private func lastPolygon() -> Polygon? {
    return polygonList.last
  }
}
