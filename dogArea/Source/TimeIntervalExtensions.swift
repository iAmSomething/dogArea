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
    var simpleWalkingTimeInterval: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60 / 1
        if hours == 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    var createdAtTimeDescription: String {
        let date = Date(timeIntervalSince1970: self)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM월dd일HH시mm분SS초"
        let formattedDate = dateFormatter.string(from: date)
        return formattedDate
    }
    var createdAtTimeYYMMDD: String {
        let date = Date(timeIntervalSince1970: self)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY년 MM월 dd일\nHH시 mm분 SS초"
        let formattedDate = dateFormatter.string(from: date)
        return formattedDate
    }
    var createdAtTimeHHMM: String {
        let date = Date(timeIntervalSince1970: self)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "💦 HH시 mm분 ss"
        let formattedDate = dateFormatter.string(from: date)
        return formattedDate
    }
    
}
