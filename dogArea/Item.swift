//
//  Item.swift
//  dogArea
//
//  Created by 김태훈 on 10/12/23.
//

import Foundation
import SwiftData
import MapKit
@Model
final class Item {
    var timestamp: Date
    var polygons: MKPolygon
    init(timestamp: Date, polygons: MKPolygon) {
        self.timestamp = timestamp
        self.polygons = polygons
    }
}
extension Optional {
    var isNil: Bool {
        return self == nil
    }
}
