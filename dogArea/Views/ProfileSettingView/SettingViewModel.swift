//
//  SettingViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/13/23.
//

import Foundation
import SwiftUI
final class SettingViewModel: ObservableObject, CoreDataProtocol {
    @Environment(\.managedObjectContext) private var viewContext
    @Published var polygonList: [Polygon] = []
    init() {
        fetchModel()
    }
    func fetchModel() {
        self.polygonList = self.fetchPolygons()
        
    }
}
