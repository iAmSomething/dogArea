//
//  MapModel.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import Foundation
import CoreLocation
import SwiftUI
import MapKit
import _MapKit_SwiftUI

struct Location: Identifiable {
  let createdAt: Double
  let id: UUID
  let coordinate: CLLocationCoordinate2D
  init(coordinate: CLLocationCoordinate2D, id: UUID, createdAt: Double) {
    self.id = id
    self.coordinate = coordinate
    self.createdAt = createdAt
  }
  init(coordinate: CLLocationCoordinate2D) {
    self.id = UUID()
    self.coordinate = coordinate
    self.createdAt = Date().timeIntervalSince1970
  }
}
extension Location : Equatable {
  static func == (lhs: Location, rhs: Location) -> Bool { lhs.id == rhs.id }
}
struct Polygon: Identifiable {
  var id: UUID
  var locations: [Location]
  var createdAt: Double
  var polygon: MKPolygon?
  
  init(locations: [Location] = []) {
    self.locations = locations
    self.id = UUID()
    self.polygon = MKPolygon(coordinates: locations.map{$0.coordinate}, count: locations.count)
    self.polygon?.title = "🐶"
    self.createdAt = Date().timeIntervalSince1970
  }
  init(locations: [Location] = [], createdAt: Double,id: UUID) {
    self.locations = locations
    self.id = id
    self.polygon = MKPolygon(coordinates: locations.map{$0.coordinate}, count: locations.count)
    self.polygon?.title = "🐶"
    self.createdAt = createdAt
  }
}
extension Polygon {
  mutating func addPoint(_ loc : Location) {
    self.locations.append(loc)
  }
  mutating func makePolygon() {
    refreshPolygon()
  }
  mutating func removeAt(_ loc : Location) {
    self.locations = self.locations.filter{$0 != loc}
    if polygon != nil && locations.count > 2{
      refreshPolygon()
    }
    else {
      polygon = nil
    }
  }
  mutating func removeAt(_ uid : UUID) {
    self.locations = self.locations.filter{$0.id != uid}
    if polygon != nil  && locations.count > 2{
      refreshPolygon()
    }
    else {
      polygon = nil
      self.locations = []
    }
  }
  mutating func clear() {
    self.locations = []
    if polygon != nil {
      refreshPolygon()
    }
  }

  private mutating func refreshPolygon() {
    self.createdAt = Date().timeIntervalSince1970
    self.id = UUID()
    let points = locations.map{MKMapPoint($0.coordinate)}
    self.polygon = MKPolygon(points: points, count: points.count)
    self.polygon?.title = "🐶"

  }
}
