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
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    
    init(coordinate: CLLocationCoordinate2D) {
        self.id = UUID()
        self.coordinate = coordinate
    }
}
extension Location : Equatable {
  static func == (lhs: Location, rhs: Location) -> Bool { lhs.id == rhs.id }
}
struct Polygon {
  var locations: [Location]
  var polygon: MKPolygon
  var polygonMapContent: MapPolygon

  init(locations: [Location] = []) {
    self.locations = locations
    
    self.polygon = MKPolygon(coordinates: locations.map{$0.coordinate}, count: locations.count)
    self.polygonMapContent = .init(polygon)
  }
}
extension Polygon {
  mutating func addPoint(_ loc : Location) {
      self.locations.append(loc)
      refreshPolygon()
  }
  mutating func removeAt(_ loc : Location) {
      self.locations = self.locations.filter{$0 != loc}
      refreshPolygon()
  }
  mutating func removeAt(_ uid : UUID) {
    self.locations = self.locations.filter{$0.id != uid}
      refreshPolygon()
  }
  mutating func clear() {
      self.locations = []
      refreshPolygon()
  }
  private mutating func refreshPolygon() {
      let points = locations.map{MKMapPoint($0.coordinate)}
      self.polygon = MKPolygon(points: points, count: points.count)
  }
}
