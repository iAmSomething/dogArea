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
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
extension Optional {
    var isNil: Bool {
        return self == nil
    }
    var isNotNil: Bool {
        return !isNil
    }
}
extension Date {
    func currentTimeMillis() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
}
