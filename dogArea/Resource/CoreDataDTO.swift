//
//  CoreDataDTO.swift
//  dogArea
//
//  Created by 김태훈 on 10/20/23.
//

import Foundation

extension PolygonEntity {
  func toPolygon() -> Polygon? {
    var locations = [Location]()
    guard
      let id = self.uuid,
      let locationEntities = self.locations?.array as? [LocationEntity]
    else {
      return nil
    }
    for entity in locationEntities {
      if let location = entity.toLocation() {
        locations.append(location)
      }
    }
    return Polygon(locations: locations, createdAt: Double(self.createdAt), id:id)
  }
}

extension LocationEntity {
  func toLocation() -> Location? {
    guard
      let id = self.uuid,
      let x = self.x,
      let y = self.y,
      let createdAt = self.createdAt
    else {
      return nil
    }
    return Location.init(coordinate: .init(latitude: Double(truncating: x), longitude: Double(truncating: y)), id: id, createdAt: Double(truncating: createdAt))
  }
}
