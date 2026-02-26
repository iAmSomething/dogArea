//
//  WalkListViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import Foundation
import Combine
final class WalkListViewModel: ObservableObject, CoreDataProtocol {
    @Published var walkingDatas: [WalkDataModel] = []
    func fetchModel() {
        self.walkingDatas = self.fetchPolygons().map{
            .init(polygon: $0)
        }
    }

}
