//
//  LocationManager.swift
//  dogArea
//
//  Created by 김태훈 on 10/12/23.
//
import CoreLocation
import Foundation
import MapKit
import Combine
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate{
    @Published var location:(Double, Double) = (0.0,0.0)
    private var locationManager = CLLocationManager()
    private var currentCoordinate: CLLocationCoordinate2D?
    override init() {
        super.init()
        self.configure()
    }
    private func configure() {
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        let status = locationManager.authorizationStatus
        switch status {
        case .denied, .restricted, .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            print("권한 설정 완")
            locationManager.requestLocation()
        case .authorizedWhenInUse:
            //팝업 불러와서 설정 해주기
            locationManager.requestAlwaysAuthorization()
        }
    }
   
}
extension LocationManager{
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.currentCoordinate = locations.last?.coordinate
        if let lat = self.currentCoordinate?.latitude, let long = self.currentCoordinate?.longitude {
            self.location = (lat.magnitude, long.magnitude)
            print(self.location)
            print("값 변경")
        }
        print("\(locations.map{($0.coordinate.latitude , $0.coordinate.longitude)})")
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
            
        case .notDetermined, .restricted, .denied:
            print("권한 재설정 요청")
            locationManager.requestAlwaysAuthorization()

        case .authorizedAlways, .authorizedWhenInUse:
            self.currentCoordinate = manager.location?.coordinate
        }
    }
    func callLocation() {
        self.locationManager.requestLocation()
    }
}
