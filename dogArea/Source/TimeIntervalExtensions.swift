//
//  TimeIntervalExtensions.swift
//  dogArea
//
//  Created by 김태훈 on 11/13/23.
//

import Foundation

extension TimeInterval {

    var walkingTimeInterval: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60 / 1
        
        return String(format: "%02d시간 %02d분 %02d초", hours, minutes, seconds)
        
    }
    /**시간이 0 이면 "%02d:%02d", minutes, seconds
     시간이 0보다 크면 "%02d:%02d:%02d", hours, minutes, seconds
     */
    var simpleWalkingTimeInterval: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60 / 1
        if hours == 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    /**"MM월dd일HH시mm분ss초"*/
    var createdAtTimeDescription: String {
        let date = Date(timeIntervalSince1970: self)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM월dd일HH시mm분ss초"
        let formattedDate = dateFormatter.string(from: date)
        return formattedDate
    }
    /**"MM월dd일HH시"*/
    var createdAtTimeDescriptionSimple: String {
        let date = Date(timeIntervalSince1970: self)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM월dd일HH시"
        let formattedDate = dateFormatter.string(from: date)
        return formattedDate
    }
    /**"YYYY년 MM월 dd일\nHH시 mm분 ss초"*/
    var createdAtTimeYYMMDD: String {
        let date = Date(timeIntervalSince1970: self)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY년 MM월 dd일\nHH시 mm분 ss초"
        let formattedDate = dateFormatter.string(from: date)
        return formattedDate
    }
    /**"💦 HH시 mm분 ss"*/
    var createdAtTimeHHMM: String {
        let date = Date(timeIntervalSince1970: self)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "💦 HH시 mm분 ss"
        let formattedDate = dateFormatter.string(from: date)
        return formattedDate
    }
    func createdAtTimeCustom(format: String) -> String {
        let date = Date(timeIntervalSince1970: self)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        let formattedDate = dateFormatter.string(from: date)
        return formattedDate
    }
    var calculatedAreaString: String {
        let area = self
        var str = String(format: "%.2f" , area) + "㎡"
        if area > 10000.0 {
            str = String(format: "%.2f" , area/10000) + "만 ㎡"
        }
        if area > 100000.0 {
            str = String(format: "%.2f" , area/1000000) + "k㎡"
        }
        return str
    }
}
