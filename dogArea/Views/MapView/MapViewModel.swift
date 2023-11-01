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
class MapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
  @Environment(\.managedObjectContext) private var viewContext
  
  private let context = PersistenceController.shared.container.viewContext
  private let fetchRequest = NSFetchRequest<PolygonEntity>(entityName: "PolygonEntity")
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
    self.fetchPolygons()
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
        deletePolygon(id: polygon.id)
        polygonList.removeAll(where: {$0.id == polygon.id})
      }
    }
  }
  
  func endWalk(){
    if isWalking {
      timer?.invalidate()
      timer = nil
      time = 0.0
      polygon.makePolygon()
      if polygon.locations.count > 2{
        savePolygon()
      }
    }
    else {
      setTrackingMode()
      timerSet()
      polygon.clear()
    }
    isWalking.toggle()
    
  }
  func timerSet() {
    
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
      self.time += t.timeInterval
      #if DEBUG
      if Int(self.time) % 10 == 0 {
        self.addLocation()
      }
      #endif
    }
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
}
// MARK: 코어데이터 관련 Functions
extension MapViewModel {
  private func savePolygon () {
    let polygons = PolygonEntity(context: context)
    polygons.uuid = polygon.id
    
    polygons.createdAt = polygon.createdAt
    for location in polygon.locations {
      let locationEntity = LocationEntity(context: context)
      locationEntity.x = (location.coordinate.latitude) as NSNumber
      locationEntity.y = (location.coordinate.longitude) as NSNumber
      locationEntity.createdAt = (location.createdAt) as NSNumber
      locationEntity.uuid = location.id
      polygons.addToLocations(locationEntity)
    }
    do {
      try context.save()
      polygonList.append(polygon)
      print("Saved successfully!")
      
    } catch let error as NSError {
      print("Could not save. \(error), \(error.userInfo)")
    }
  }
  private func fetchPolygons(){
    do {
      // Perform the fetch request
      let polygons = try context.fetch(fetchRequest)
      let temp = polygons.map{$0.toPolygon()}.filter{!$0.isNil}.map{$0!}
      polygonList = temp
      print(temp.map{$0.id.uuidString})
    } catch let error as NSError {
      print("Could not fetch. \(error), \(error.userInfo)")
      polygonList = []
    }
  }
  func deletePolygon(id: UUID) {
    // Set the predicate to filter by id
    let predicate = NSPredicate(format: "uuid == %@", id as CVarArg)
    fetchRequest.predicate = predicate
    do {
      // Perform the fetch request
      let polygons = try context.fetch(fetchRequest)
      
      if let polygonToDelete = polygons.first {
        // Delete the found PolygonEntity from the context
        context.delete(polygonToDelete)
        
        // Save changes in the context
        try context.save()
        print("Deleted successfully!")
        self.polygonList.removeAll(where: {$0.id == id})
        if self.polygon.id == id {
          self.polygon.clear()
        }
      } else {
        print("No PolygonEntity found with createdAt \(id)")
      }
      
    } catch let error as NSError {
      print("Could not delete. \(error), \(error.userInfo)")
    }
  }
  private func lastPolygon() -> Polygon? {
    return polygonList.last
  }
#if DEBUG
  func deleteAllPolygons() {
    do {
      // Perform the fetch request
      let polygons = try context.fetch(fetchRequest)
      for polygon in polygons {
        // Delete each PolygonEntity from the context
        context.delete(polygon)
      }
      // Save changes in the context
      try context.save()
      print("All polygons deleted successfully!")
    } catch let error as NSError {
      print("Could not delete. \(error), \(error.userInfo)")
    }
  }
#endif

}
//        self.deleteAllPolygons()
