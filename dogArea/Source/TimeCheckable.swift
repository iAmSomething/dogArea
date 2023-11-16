//
//  TimeCheckable.swift
//  dogArea
//
//  Created by 김태훈 on 11/16/23.
//

import Foundation
protocol TimeCheckable {
    var createdAt: TimeInterval { get set }
}
extension TimeCheckable {
    func createdAtStr(type : dateFormatType) -> String {
        switch type {
        case .Description:
            self.createdAt.createdAtTimeDescription
        case .DescriptionSimple:
            self.createdAt.createdAtTimeDescriptionSimple
        case .YYMMDD:
            self.createdAt.createdAtTimeYYMMDD
        case .HHMM:
            self.createdAt.createdAtTimeHHMM
        case .custom(format: let format):
            self.createdAt.createdAtTimeCustom(format: format)
        }
    }
}
enum dateFormatType {
    case Description
    case DescriptionSimple
    case YYMMDD
    case HHMM
    case custom(format: String)
}
extension Array where Element: TimeCheckable {
    var thisWeekList:[Element] {
        let currentDate = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate)
        guard let startOfWeek = calendar.date(from: components) else {
            fatalError("Failed to calculate the start of the week.")
        }
        guard calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) != nil else {
            fatalError("Failed to calculate the end of the week.")
        }
        let thisWeek = self.filter{e in
            let date = Date(timeIntervalSince1970: e.createdAt)
            let roundedDate = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: date)!
            return roundedDate > startOfWeek
        }
        return thisWeek
    }
    var exceptThisWeek: [Element] {
        let thisweek = self.thisWeekList
        let temp = thisweek.map{$0.createdAt}
        let result = self.filter{!temp.contains($0.createdAt)}
        return result
    }
}

