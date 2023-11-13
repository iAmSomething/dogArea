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
            .init(polygon: $0, image: $0.binaryImage == nil ? nil : UIImage(data: $0.binaryImage!))
        }
    }
}
