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
    @Published var myAreaList: [AreaMeterDTO] = []
    @Published var userInfo: UserInfo? = nil
    init() {
        fetchData()
        totalArea = polygonList.map{$0.walkingArea}.reduce(0.0){$0 + $1}
        totalTime = polygonList.map{$0.walkingTime}.reduce(0.0){$0 + $1}
        myArea = .init("\(UserdefaultSetting().getValue()?.pet.first?.petName.addYi() ?? "강아지")의 영역", totalArea)
        myAreaList = fetchArea()
        if let info = UserdefaultSetting().getValue() {
            userInfo = info
        } else {
            //로그아웃 액션
        }
    }
    func fetchData() {
        polygonList = fetchPolygons()
        updateCurrentMeter()
        
    }
    func refreshAreaList () {
        myAreaList = fetchArea()
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
    private func shouldUpdateMeter() -> Bool{
        // 코어데이터가 비어있고
        guard let last = fetchArea().last else {return true}
        guard let current = nearlistLess() else {return false}
        // 만약 코어데이터 최근 값과 정복한 영역이 같다면 업데이트를 안 해 준다.
        if (last.area == current.area && last.areaName == current.areaName) {
            return false
        } else if last.area > current.area {
            return false
        } else {
            return true
        }
    }
    private func updateCurrentMeter() {
        if shouldUpdateMeter() {
            var currents = krAreas.nearistArea(since: fetchArea().last, from: myArea.area)
            for c in currents.reversed() {
                if saveArea(area: .init(areaName: c.areaName, area: c.area, createdAt: Date().timeIntervalSince1970)) {
                    print("저장 성공")
                }
            }
        }
    }
    func walkedDates() -> Array<Date> {
        let dateArr = polygonList.map{Date(timeIntervalSince1970:$0.createdAt)}
            .map{Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: $0)!}
        return dateArr
    }
    func walkedAreaforWeek() -> Double {
        let polygonListWeek = polygonList.thisWeekList
        let areaWeek = polygonListWeek.map{$0.walkingArea}.reduce(0.0){$0 + $1}
        return areaWeek
    }
    func walkedCountforWeek() -> Int {
        let polygonListWeek = polygonList.thisWeekList
        return polygonListWeek.count
    }
//#if DEBUG
//    func makeitup() {
//        withAnimation{
//            myArea.area += 1000000.0
//        }
//    }
//    func reset() {
//        withAnimation{
//            myArea = .init("강아지의 영역", totalArea)
//            clear()
//        }
//    }
//    func clear() {
//        deleteArea()
//    }
//#endif
}
