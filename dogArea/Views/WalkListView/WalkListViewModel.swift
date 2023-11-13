//
//  WalkListViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import Foundation
import SwiftUI
import CoreData
final class WalkListViewModel: ObservableObject, CoreDataProtocol {
    @Environment(\.managedObjectContext) private var viewContext
    @Published var walkingDatas: [WalkDataModel] = []
    func fetchModel() {
        self.walkingDatas = self.fetchPolygons().map{
            .init(polygon: $0)
        }
    }
    func calculatedAreaString(areaSize: Double , isPyong: Bool = false) -> String {
        var str = String(format: "%.2f" , areaSize) + "㎡"
        if areaSize > 10000.0 {
            str = String(format: "%.2f" , areaSize/10000) + "만 ㎡"
        }
        if areaSize > 100000.0 {
            str = String(format: "%.2f" , areaSize/1000000) + "k㎡"
        }
        if isPyong {
            if areaSize/3.3 > 10000 {
                str = String(format: "%.1f" , areaSize/33333) + "만 평"

            } else {
                str = String(format: "%.1f" , areaSize/3.3) + "평"
            }
        }
        return str
    }
}
