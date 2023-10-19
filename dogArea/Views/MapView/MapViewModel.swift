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
class MapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private var timer: Timer? = nil
  @Published var time: TimeInterval = 0.0
  @Published var startTime = Date()
  @Published var location: CLLocation? // 현재 위치 정보
  @Published var polygon : Polygon = .init()
  @Published var isWalking: Bool = false
  override init() {
    super.init()
    self.locationManager.delegate = self
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest // 정확도 설정
    self.locationManager.requestWhenInUseAuthorization() // 권한 요청
    self.locationManager.startUpdatingLocation() // 위치 업데이트 시작
  }
  
  func addLocation(){
    if let location=self.location{
      polygon.addPoint(.init(coordinate: location.coordinate))
    }
  }
  
  func removeLocation(_ locationID : UUID){
    if let index=polygon.locations.firstIndex(where:{ $0.id == locationID}){
      polygon.removeAt(locationID)
    }
  }
  
  func endWalk(){
    if isWalking {
      timer?.invalidate()
      timer = nil
      time = 0.0
      polygon.clear()
    }
    else {
      timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { t in
        self.time += t.timeInterval
      }
    }
    isWalking.toggle()
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    location = locations.last // 가장 최근의 위치 정보 저장
  }
}
extension MapViewModel {
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .notDetermined, .restricted, .denied:
      locationManager.requestAlwaysAuthorization()
    case .authorizedAlways, .authorizedWhenInUse:
      print("good")

    @unknown default:
      locationManager.requestAlwaysAuthorization()
    }
  }
  func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
    print(manager.location?.description)
  }
}
