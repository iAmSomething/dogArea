//
//  RankingViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import Foundation
import SwiftUI
import CoreData
final class RankingViewModel: ObservableObject, CoreDataProtocol {
  @Environment(\.managedObjectContext) private var viewContext
  @Published var walkingDatas: [WalkDataModel] = []
  init() {
    self.walkingDatas = self.fetchPolygons().map{.init(polygon: $0)}
  }
}
