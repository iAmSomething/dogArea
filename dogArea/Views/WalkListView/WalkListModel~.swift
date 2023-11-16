//
//  WalkListModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import Foundation
import UIKit
import MapKit
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
    func toLocation() -> Location {
        .init(coordinate: .init(latitude: coordinateX, longitude: coordinateY), id: id, createdAt: createdAt)
    }
    var coordinate: CLLocationCoordinate2D {
        return .init(latitude: self.coordinateX, longitude: self.coordinateY)
    }
}
struct WalkDataModel: Identifiable, Hashable {
    let id: UUID
    let locations: [WalkPosition]
    let createdAt: Double
    let image: UIImage?
    let walkDuration: Double
    let walkArea: Double
    init(polygon: Polygon) {
        self.id = polygon.id
        self.createdAt = polygon.createdAt
        self.locations = polygon.locations.map{.init(location: $0)}
        self.walkArea = polygon.walkingArea
        self.walkDuration = polygon.walkingTime
        if let imgData = polygon.binaryImage {
            self.image = UIImage(data: imgData)
        } else { self.image = nil}
    }
    func toPolygon() -> Polygon {
        .init(locations: self.locations.map{$0.toLocation()}, createdAt: createdAt, id: id, walkingTime: walkDuration, walkingArea: walkArea, imgData: nil)
    }
}
