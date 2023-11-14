//
//  HomeViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/14/23.
//

import Foundation
import SwiftUI
final class HomeViewModel: ObservableObject, CoreDataProtocol {
    @Published var polygonList: [Polygon] = []
    @Published var totalArea: Double = 0.0
    @Published var totalTime: Double = 0.0
    @Published var krAreas: AreaMeterCollection = .init()
    @Published var myArea: AreaMeter = .init("", 0.0)
    init() {
        fetchData()
        totalArea = polygonList.map{$0.walkingArea}.reduce(0.0){$0 + $1}
        totalTime = polygonList.map{$0.walkingTime}.reduce(0.0){$0 + $1}
        myArea = .init("강아지의 영역", totalArea)
    }
    private func fetchData() {
        polygonList = fetchPolygons()
    }
    private func findIndex() -> Int {
        guard let i = krAreas.areas.firstIndex(where: {
            $0.area < myArea.area
        }) else {return krAreas.areas.count}
        return i
    }
    func combinedAreas() -> [AreaMeter] {
        let i = findIndex()
        var temp = krAreas.areas
        temp.insert(myArea, at: i)
        return temp
    }
    func nearlistLess() -> AreaMeter? {
        krAreas.nearistArea(of: myArea.area)
    }
    func nearlistMore() -> AreaMeter? {
        krAreas.closeArea(of: myArea.area)
    }
    #if DEBUG
    func makeitup() {
        withAnimation{
            myArea.area += 50000000.0
        }
    }
    func reset() {
        withAnimation{
            myArea = .init("강아지의 영역", totalArea)
        }
    }
    #endif
}
