//
//  WalkListModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import Foundation
import UIKit
struct WalkPosition: Identifiable, Hashable {
  let createdAt: Double
  let id: UUID
  let coordinateX: Double
  let coordinateY: Double
  init(location: Location) {
    self.id = location.id
    self.createdAt = location.createdAt
    self.coordinateX = location.coordinate.latitude
    self.coordinateY = location.coordinate.longitude
  }
}
struct WalkDataModel: Identifiable, Hashable {
  var id: UUID
  var locations: [WalkPosition]
  var createdAt: Double
  var image: UIImage?
  init(polygon: Polygon, image: UIImage? = nil) {
    self.id = polygon.id
    self.createdAt = polygon.createdAt
    self.image = image
    self.locations = polygon.locations.map{.init(location: $0)}
  }
}
