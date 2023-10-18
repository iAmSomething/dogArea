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
import UIKit
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate, MKMapViewDelegate{
    @Published var location:(Double, Double) = (0.0,0.0)
    @Published var mapView: MKMapView = .init()
    @Published var polygon = Polygon()
    @Published var alertId: String = ""
    private var locationManager = CLLocationManager()
    private var currentCoordinate: CLLocationCoordinate2D?
    override init() {
        super.init()
        self.configure()
    }
    private func configure() {
        locationManager.delegate = self
        mapView.delegate = self
        locationManager.requestAlwaysAuthorization()
        let status = locationManager.authorizationStatus
        switch status {
        case .denied, .restricted, .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            mapViewConfigure()
            locationManager.requestLocation()
        case .authorizedWhenInUse:
            //팝업 불러와서 설정 해주기
            locationManager.requestAlwaysAuthorization()
        }
    }
    private func mapViewConfigure() {
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsUserTrackingButton = true
        mapView.isRotateEnabled = true
        mapView.showsScale = true
        mapView.contentScaleFactor = 0.5
        mapView.showsUserTrackingButton = true
        mapView.setUserTrackingMode(.followWithHeading, animated: true)
        
        let an = MKPointAnnotation(__coordinate: mapView.camera.centerCoordinate)
    }
   
}
// MARK: CLLocatioinManager Extentions
extension LocationManager{
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.currentCoordinate = locations.last?.coordinate
        if let lat = self.currentCoordinate?.latitude, let long = self.currentCoordinate?.longitude {
            self.location = (lat.magnitude, long.magnitude)
        }
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
}
// MARK: mapView Extentions
extension LocationManager {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
      if overlay is MKPolygon {
        let polygonView = MKPolygonRenderer(overlay: overlay)
          polygonView.strokeColor = .black
          polygonView.lineWidth = 1.0
          polygonView.fillColor = .blue.withAlphaComponent(0.25)
          return polygonView
      }
      return MKOverlayRenderer()
    }
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        print("알림 띄워주는 로직 필요 합니다.")
    }
}
// MARK: custom functions
extension LocationManager {
    func callLocation() {
        let an = MKPointAnnotation(__coordinate: self.mapView.region.center)
        self.polygon.addPoint(.init(annotation: an))
        if self.mapView.annotations.count > 1 {
            self.mapView.deselectAnnotation(self.mapView.annotations.last!, animated: true)
        }
        self.mapView.addAnnotation(an)
        self.mapView.selectAnnotation(an, animated: true)
        self.locationManager.requestLocation()
        updatePolygon()
    }
    private func updatePolygon() {
        self.mapView.removeOverlay(self.polygon.polygon)
        mapView.addOverlay(self.polygon.polygon)
        print(self.mapView.annotations.description)
    }

    func clear() {
        self.mapView.removeAnnotations(self.mapView.annotations)
        self.polygon.clear()
        updatePolygon()
    }
    func removePoint(loc: Location) {
        self.polygon.removeAt(loc)
        updatePolygon()
    }
}
