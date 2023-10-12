//
//  Item.swift
//  dogArea
//
//  Created by 김태훈 on 10/12/23.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
