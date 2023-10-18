//
//  Location.swift
//  dogArea
//
//  Created by 김태훈 on 10/16/23.
//

import Foundation
import MapKit
import SwiftUI

// 로케이션 구조체
struct Location: Equatable, Comparable {
    //시간 순서
    static func < (lhs: Location, rhs: Location) -> Bool {
        lhs.createdAt < rhs.createdAt
    }
    static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.id == rhs.id
    }
    let id: String
    let createdAt: Int64
    let annotation: MKAnnotation
    let coordinate: CLLocationCoordinate2D
    init( annotation: MKAnnotation, _ createdAt: Int64 = 0) {
        let date = Date()
        let uuid = NSUUID().uuidString
        self.createdAt = date.currentTimeMillis()
        self.id = uuid
        self.annotation = annotation
        self.coordinate = CLLocationCoordinate2D(latitude: annotation.coordinate.latitude,
                                                 longitude: annotation.coordinate.longitude)
    }
}
// 폴리곤 구조체
struct Polygon : Observable {
    @State var didSelect: Bool = false
    var selectedLocations: [Location]
    var polygon : MKPolygon

    init(locations: [Location] = []) {
        self.selectedLocations = locations
        let points = locations.map{MKMapPoint($0.coordinate)}
        self.polygon = MKPolygon(points: points, count: points.count)
    }
    mutating func addPoint(_ loc : Location) {
        self.selectedLocations.append(loc)
        refreshPolygon()
    }
    mutating func removeAt(_ loc : Location) {
        self.selectedLocations = self.selectedLocations.filter{$0 != loc}
        refreshPolygon()
    }
    mutating func clear() {
        self.selectedLocations = []
        refreshPolygon()
    }
    private mutating func refreshPolygon() {
        let points = selectedLocations.map{MKMapPoint($0.coordinate)}
        self.polygon = MKPolygon(points: points, count: points.count)
    }

}
