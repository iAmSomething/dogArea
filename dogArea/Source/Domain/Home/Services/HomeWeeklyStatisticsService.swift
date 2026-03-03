//
//  HomeWeeklyStatisticsService.swift
//  dogArea
//
//  Created by Codex on 3/2/26.
//

import Foundation

protocol HomeWeeklyStatisticsServicing {
    /// 기준 시점이 포함된 주(week)의 시작/종료 구간을 계산합니다.
    /// - Parameters:
    ///   - reference: 주간 구간을 계산할 기준 시각입니다.
    ///   - calendar: 주 시작 규칙과 타임존이 반영된 캘린더입니다.
    /// - Returns: 기준 시점이 속한 주의 `DateInterval`입니다.
    func currentWeekInterval(reference: Date, calendar: Calendar) -> DateInterval

    /// 산책 세션(폴리곤)의 실제 시간 구간을 계산합니다.
    /// - Parameter polygon: 산책 시작 시각(`createdAt`)과 지속 시간(`walkingTime`)을 가진 기록입니다.
    /// - Returns: 산책 세션의 시작/종료 시각 구간입니다. duration이 0 이하이면 최소 1초 구간을 반환합니다.
    func sessionInterval(for polygon: Polygon) -> DateInterval

    /// 산책 세션이 특정 구간에 기여하는 면적을 비율로 계산합니다.
    /// - Parameters:
    ///   - polygon: 기여 면적을 계산할 산책 기록입니다.
    ///   - bucket: 면적을 집계할 대상 시간 구간입니다.
    /// - Returns: 세션과 대상 구간의 겹침 비율이 반영된 면적 값입니다.
    func weightedAreaContribution(for polygon: Polygon, in bucket: DateInterval) -> Double

    /// 산책 세션이 특정 구간에 기여하는 시간을 비율로 계산합니다.
    /// - Parameters:
    ///   - polygon: 기여 시간을 계산할 산책 기록입니다.
    ///   - bucket: 시간을 집계할 대상 시간 구간입니다.
    /// - Returns: 세션과 대상 구간의 겹침 비율이 반영된 시간(초) 값입니다.
    func weightedDurationContribution(for polygon: Polygon, in bucket: DateInterval) -> Double

    /// 산책 세션과 대상 구간이 실제로 겹치는지 판단합니다.
    /// - Parameters:
    ///   - polygon: 겹침 여부를 판단할 산책 기록입니다.
    ///   - bucket: 겹침을 확인할 대상 구간입니다.
    /// - Returns: 두 구간이 1초 이상 겹치면 `true`, 아니면 `false`입니다.
    func sessionOverlaps(_ polygon: Polygon, with bucket: DateInterval) -> Bool

    /// 산책 세션이 커버하는 날짜의 `startOfDay` 목록을 계산합니다.
    /// - Parameters:
    ///   - polygon: 날짜 경계를 걸칠 수 있는 산책 기록입니다.
    ///   - calendar: 날짜 경계 계산에 사용할 캘린더입니다.
    /// - Returns: 세션이 걸친 날짜들의 시작 시각 배열입니다.
    func dayStartsCovered(by polygon: Polygon, calendar: Calendar) -> [Date]

    /// 전체 산책 목록에서 중복 없는 산책 날짜 목록을 계산합니다.
    /// - Parameters:
    ///   - polygonList: 화면에 반영할 산책 기록 목록입니다.
    ///   - calendar: 날짜 경계 계산에 사용할 캘린더입니다.
    /// - Returns: 오름차순 정렬된 날짜 시작 시각 배열입니다.
    func walkedDates(from polygonList: [Polygon], calendar: Calendar) -> [Date]

    /// 기준 주간에 해당하는 누적 산책 면적을 계산합니다.
    /// - Parameters:
    ///   - polygonList: 집계 대상 산책 기록 목록입니다.
    ///   - reference: 주간 계산 기준 시각입니다.
    ///   - calendar: 주간 경계 계산에 사용할 캘린더입니다.
    /// - Returns: 기준 주간에 속한 총 산책 면적입니다.
    func walkedAreaForWeek(from polygonList: [Polygon], reference: Date, calendar: Calendar) -> Double

    /// 기준 주간에 겹친 산책 세션 개수를 계산합니다.
    /// - Parameters:
    ///   - polygonList: 집계 대상 산책 기록 목록입니다.
    ///   - reference: 주간 계산 기준 시각입니다.
    ///   - calendar: 주간 경계 계산에 사용할 캘린더입니다.
    /// - Returns: 기준 주간과 겹치는 세션 수입니다.
    func walkedCountForWeek(from polygonList: [Polygon], reference: Date, calendar: Calendar) -> Int

    /// 자정 경계를 걸친 산책 세션의 전일/당일 기여도를 계산합니다.
    /// - Parameters:
    ///   - polygonList: 집계 대상 산책 기록 목록입니다.
    ///   - reference: 당일 기준 시각입니다.
    ///   - calendar: 날짜 경계 계산에 사용할 캘린더입니다.
    /// - Returns: 경계 분배 결과 DTO이며, 해당 세션이 없으면 `nil`입니다.
    func makeDayBoundarySplitContribution(
        from polygonList: [Polygon],
        reference: Date,
        calendar: Calendar
    ) -> DayBoundarySplitContribution?
}

final class HomeWeeklyStatisticsService: HomeWeeklyStatisticsServicing {
    /// 기준 시점이 포함된 주(week)의 시작/종료 구간을 계산합니다.
    /// - Parameters:
    ///   - reference: 주간 구간을 계산할 기준 시각입니다.
    ///   - calendar: 주 시작 규칙과 타임존이 반영된 캘린더입니다.
    /// - Returns: 기준 시점이 속한 주의 `DateInterval`입니다.
    func currentWeekInterval(reference: Date, calendar: Calendar) -> DateInterval {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: reference)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: reference)
        let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start.addingTimeInterval(7 * 24 * 3600)
        return DateInterval(start: start, end: end)
    }

    /// 산책 세션(폴리곤)의 실제 시간 구간을 계산합니다.
    /// - Parameter polygon: 산책 시작 시각(`createdAt`)과 지속 시간(`walkingTime`)을 가진 기록입니다.
    /// - Returns: 산책 세션의 시작/종료 시각 구간입니다. duration이 0 이하이면 최소 1초 구간을 반환합니다.
    func sessionInterval(for polygon: Polygon) -> DateInterval {
        let start = Date(timeIntervalSince1970: polygon.createdAt)
        let duration = max(0, polygon.walkingTime)
        if duration <= 0 {
            return DateInterval(start: start, end: start.addingTimeInterval(1))
        }
        return DateInterval(start: start, end: start.addingTimeInterval(duration))
    }

    /// 산책 세션이 특정 구간에 기여하는 면적을 비율로 계산합니다.
    /// - Parameters:
    ///   - polygon: 기여 면적을 계산할 산책 기록입니다.
    ///   - bucket: 면적을 집계할 대상 시간 구간입니다.
    /// - Returns: 세션과 대상 구간의 겹침 비율이 반영된 면적 값입니다.
    func weightedAreaContribution(for polygon: Polygon, in bucket: DateInterval) -> Double {
        let duration = max(0, polygon.walkingTime)
        let area = max(0, polygon.walkingArea)
        if duration <= 0 {
            let point = Date(timeIntervalSince1970: polygon.createdAt)
            return bucket.contains(point) ? area : 0
        }

        let overlap = overlapSeconds(sessionInterval(for: polygon), bucket)
        guard overlap > 0 else { return 0 }
        let ratio = min(1, overlap / duration)
        return area * ratio
    }

    /// 산책 세션이 특정 구간에 기여하는 시간을 비율로 계산합니다.
    /// - Parameters:
    ///   - polygon: 기여 시간을 계산할 산책 기록입니다.
    ///   - bucket: 시간을 집계할 대상 시간 구간입니다.
    /// - Returns: 세션과 대상 구간의 겹침 비율이 반영된 시간(초) 값입니다.
    func weightedDurationContribution(for polygon: Polygon, in bucket: DateInterval) -> Double {
        let duration = max(0, polygon.walkingTime)
        if duration <= 0 {
            let point = Date(timeIntervalSince1970: polygon.createdAt)
            return bucket.contains(point) ? duration : 0
        }

        let overlap = overlapSeconds(sessionInterval(for: polygon), bucket)
        guard overlap > 0 else { return 0 }
        let ratio = min(1, overlap / duration)
        return duration * ratio
    }

    /// 산책 세션과 대상 구간이 실제로 겹치는지 판단합니다.
    /// - Parameters:
    ///   - polygon: 겹침 여부를 판단할 산책 기록입니다.
    ///   - bucket: 겹침을 확인할 대상 구간입니다.
    /// - Returns: 두 구간이 1초 이상 겹치면 `true`, 아니면 `false`입니다.
    func sessionOverlaps(_ polygon: Polygon, with bucket: DateInterval) -> Bool {
        if max(0, polygon.walkingTime) <= 0 {
            return bucket.contains(Date(timeIntervalSince1970: polygon.createdAt))
        }
        return overlapSeconds(sessionInterval(for: polygon), bucket) > 0
    }

    /// 산책 세션이 커버하는 날짜의 `startOfDay` 목록을 계산합니다.
    /// - Parameters:
    ///   - polygon: 날짜 경계를 걸칠 수 있는 산책 기록입니다.
    ///   - calendar: 날짜 경계 계산에 사용할 캘린더입니다.
    /// - Returns: 세션이 걸친 날짜들의 시작 시각 배열입니다.
    func dayStartsCovered(by polygon: Polygon, calendar: Calendar) -> [Date] {
        let interval = sessionInterval(for: polygon)
        var dates: [Date] = []
        var cursor = calendar.startOfDay(for: interval.start)
        dates.append(cursor)

        while let next = calendar.date(byAdding: .day, value: 1, to: cursor), next < interval.end {
            dates.append(next)
            cursor = next
        }

        return dates
    }

    /// 전체 산책 목록에서 중복 없는 산책 날짜 목록을 계산합니다.
    /// - Parameters:
    ///   - polygonList: 화면에 반영할 산책 기록 목록입니다.
    ///   - calendar: 날짜 경계 계산에 사용할 캘린더입니다.
    /// - Returns: 오름차순 정렬된 날짜 시작 시각 배열입니다.
    func walkedDates(from polygonList: [Polygon], calendar: Calendar) -> [Date] {
        var dayStarts: [TimeInterval: Date] = [:]
        for polygon in polygonList {
            for day in dayStartsCovered(by: polygon, calendar: calendar) {
                dayStarts[day.timeIntervalSince1970] = day
            }
        }
        return dayStarts.values.sorted()
    }

    /// 기준 주간에 해당하는 누적 산책 면적을 계산합니다.
    /// - Parameters:
    ///   - polygonList: 집계 대상 산책 기록 목록입니다.
    ///   - reference: 주간 계산 기준 시각입니다.
    ///   - calendar: 주간 경계 계산에 사용할 캘린더입니다.
    /// - Returns: 기준 주간에 속한 총 산책 면적입니다.
    func walkedAreaForWeek(from polygonList: [Polygon], reference: Date, calendar: Calendar) -> Double {
        let weekInterval = currentWeekInterval(reference: reference, calendar: calendar)
        return polygonList.reduce(0.0) { partial, polygon in
            partial + weightedAreaContribution(for: polygon, in: weekInterval)
        }
    }

    /// 기준 주간에 겹친 산책 세션 개수를 계산합니다.
    /// - Parameters:
    ///   - polygonList: 집계 대상 산책 기록 목록입니다.
    ///   - reference: 주간 계산 기준 시각입니다.
    ///   - calendar: 주간 경계 계산에 사용할 캘린더입니다.
    /// - Returns: 기준 주간과 겹치는 세션 수입니다.
    func walkedCountForWeek(from polygonList: [Polygon], reference: Date, calendar: Calendar) -> Int {
        let weekInterval = currentWeekInterval(reference: reference, calendar: calendar)
        return polygonList.filter { sessionOverlaps($0, with: weekInterval) }.count
    }

    /// 자정 경계를 걸친 산책 세션의 전일/당일 기여도를 계산합니다.
    /// - Parameters:
    ///   - polygonList: 집계 대상 산책 기록 목록입니다.
    ///   - reference: 당일 기준 시각입니다.
    ///   - calendar: 날짜 경계 계산에 사용할 캘린더입니다.
    /// - Returns: 경계 분배 결과 DTO이며, 해당 세션이 없으면 `nil`입니다.
    func makeDayBoundarySplitContribution(
        from polygonList: [Polygon],
        reference: Date,
        calendar: Calendar
    ) -> DayBoundarySplitContribution? {
        let todayStart = calendar.startOfDay(for: reference)
        guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart),
              let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) else {
            return nil
        }

        let previousInterval = DateInterval(start: yesterdayStart, end: todayStart)
        let currentInterval = DateInterval(start: todayStart, end: tomorrowStart)

        var previousArea = 0.0
        var currentArea = 0.0
        var previousDuration = 0.0
        var currentDuration = 0.0

        for polygon in polygonList {
            let session = sessionInterval(for: polygon)
            guard session.start < todayStart && session.end > todayStart else { continue }

            previousArea += weightedAreaContribution(for: polygon, in: previousInterval)
            currentArea += weightedAreaContribution(for: polygon, in: currentInterval)
            previousDuration += weightedDurationContribution(for: polygon, in: previousInterval)
            currentDuration += weightedDurationContribution(for: polygon, in: currentInterval)
        }

        guard previousArea > 0 || currentArea > 0 || previousDuration > 0 || currentDuration > 0 else {
            return nil
        }

        return DayBoundarySplitContribution(
            previousDay: yesterdayStart,
            currentDay: todayStart,
            previousArea: previousArea,
            currentArea: currentArea,
            previousDuration: previousDuration,
            currentDuration: currentDuration
        )
    }

    /// 두 시간 구간의 겹치는 초(second)를 계산합니다.
    /// - Parameters:
    ///   - lhs: 첫 번째 시간 구간입니다.
    ///   - rhs: 두 번째 시간 구간입니다.
    /// - Returns: 겹치는 초 단위 길이입니다. 겹침이 없으면 0을 반환합니다.
    private func overlapSeconds(_ lhs: DateInterval, _ rhs: DateInterval) -> TimeInterval {
        let overlapStart = max(lhs.start, rhs.start)
        let overlapEnd = min(lhs.end, rhs.end)
        return max(0, overlapEnd.timeIntervalSince(overlapStart))
    }
}
