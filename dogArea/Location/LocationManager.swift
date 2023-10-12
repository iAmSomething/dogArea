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
    @Published var selectedAnotation: MKAnnotation?
    @Published var isnil = true
    private var coordinates: [CLLocationCoordinate2D] = []
    @Published var area: MKPolygon?
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
            mapView.showsUserLocation = true
            mapView.showsCompass = true
            mapView.showsUserTrackingButton = true
            
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
    func callLocation() {
        var an = MKPointAnnotation()
        
        an.coordinate = self.mapView.region.center
        self.coordinates.append(an.coordinate)
        if let first = self.mapView.annotations.first {
            self.mapView.deselectAnnotation(first, animated: true)
            //self.mapView.removeAnnotation(first)
        }
        self.mapView.addAnnotation(an)
        self.mapView.selectAnnotation(an, animated: true)
        self.locationManager.requestLocation()
        updatePolygon()
    }
    func updatePolygon() {
        if self.area != nil {
            self.mapView.removeOverlay(area!)
        }
        var mkpoints = self.coordinates.map{MKMapPoint($0)}
        self.area = MKPolygon(points: mkpoints, count: mkpoints.count)
        print(mkpoints.map{($0.coordinate.latitude, $0.coordinate.longitude)})
        print("")
        print(area!.pointCount)
        mapView.addOverlay(area!)
    }
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
    func clear() {
        self.mapView.removeAnnotations(self.mapView.annotations)
        self.coordinates = []
        updatePolygon()
    }
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
    }
}
