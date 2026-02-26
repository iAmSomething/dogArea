//
//  Calender.swift
//  dogArea
//
//  Created by 김태훈 on 11/14/23.
//

import SwiftUI

struct CalenderView: View {
    @State var month: Date = Date()
    @State var offset: CGSize = CGSize()
    @State var clickedDates: Array<Date>
    @Environment(\.colorScheme) var scheme
    var body: some View {
        VStack {
            headerView
            calendarGridView
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    self.offset = gesture.translation
                }
                .onEnded { gesture in
                    if gesture.translation.width < -100 {
                        changeMonth(by: 1)
                    } else if gesture.translation.width > 100 {
                        changeMonth(by: -1)
                    }
                    self.offset = CGSize()
                }
        )
    }
    
    // MARK: - 헤더 뷰
    private var headerView: some View {
        VStack {
            HStack(alignment: .bottom){
                Button(action: {changeMonth(by: -1)}, label: {
                    Text("이전 달")
                        .foregroundStyle(Color.appColor(type: .appTextBlack, scheme: scheme))
                        .font(.appFont(for: .Regular, size: 14))
                        .padding(.leading, 20)
                })
                Spacer()
                Text(month, formatter: Self.dateFormatter)
                    .font(.appFont(for: .SemiBold, size: 18))
                    .padding(.bottom)
                Spacer()
                Button(action: {changeMonth(by: 1)}, label: {
                    Text("다음 달")
                        .padding(.trailing, 20)
                        .foregroundStyle(Color.appColor(type: .appTextBlack, scheme: scheme))
                        .font(.appFont(for: .Regular, size: 14))


                })

            }
            HStack {
                ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.appFont(for: .Regular, size: 15))
                        .foregroundStyle((symbol == "Sun" || symbol == "일") ? Color.red : (symbol == "Sat" || symbol == "토") ? Color.blue : Color.appColor(type: .appTextBlack, scheme: scheme))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 5)
        }
    }
    
    // MARK: - 날짜 그리드 뷰
    private var calendarGridView: some View {
        let daysInMonth: Int = numberOfDays(in: month)
        let firstWeekday: Int = firstWeekdayOfMonth(in: month) - 1
        
        return VStack {
            LazyVGrid(columns: Array(repeating: GridItem(), count: 7)) {
                ForEach(0 ..< daysInMonth + firstWeekday, id: \.self) { index in
                    if index < firstWeekday {
                        RoundedRectangle(cornerRadius: 5)
                            .foregroundColor(Color.clear)
                    } else {
                        let date = getDate(for: index - firstWeekday)
                        let day = index - firstWeekday + 1
                        let sunday = index % 7 == 0
                        let saturday = index % 7 == 6
                        let clicked = clickedDates.filter{$0 == date}
                        let today = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date()) ?? Date()
                        CellView(day: day, clickedCount: clicked.count, sun: sunday, sat: saturday, today: today == date)
                    }
                }
            }
        }
    }
}

// MARK: - 일자 셀 뷰
private struct CellView: View {
    var sunday: Bool
    var saturday: Bool
    var day: Int
    var clickedCount: Int = 0
    var today: Bool
    @Environment(\.colorScheme) var scheme
    init(day: Int, clickedCount: Int, sun: Bool, sat: Bool, today: Bool) {
        self.day = day
        self.clickedCount = clickedCount
        self.sunday = sun
        self.saturday = sat
        self.today = today
    }
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 5)
                .opacity(0)
                .overlay(
                    Text(String(day))
                        .font(.appFont(for: .Regular, size: 15))
                        .foregroundStyle(sunday ? Color.red : saturday ? Color.blue : Color.appColor(type: .appTextBlack, scheme: scheme))
                )
                .foregroundColor(.blue)
            
            if clickedCount != 0 {
                Text(clickedCount == 1 ? "🐶" : "🐶x\(clickedCount)")
                    .font(.appFont(for: .Regular, size: 8))
                    .foregroundColor(Color.appColor(type: .appTextBlack, scheme: scheme))
                    .frame(height: 15)
            } else {
                Spacer()
                    .frame(height: 15)
                
            }
        }.frame(width: 46, height: 46)
        .background(today ? Color.appPink : .clear)
        .clipShape(RoundedCornersShape(radius: 23))
            
    }
}

// MARK: - 내부 메서드
private extension CalenderView {
    /// 특정 해당 날짜
    private func getDate(for day: Int) -> Date {
        let date = Calendar.current.date(byAdding: .day, value: day, to: startOfMonth()) ?? startOfMonth()
        return Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: date) ?? date
    }
    
    /// 해당 월의 시작 날짜
    func startOfMonth() -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: month)
        return Calendar.current.date(from: components) ?? month
    }
    
    /// 해당 월에 존재하는 일자 수
    func numberOfDays(in date: Date) -> Int {
        return Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 0
    }
    
    /// 해당 월의 첫 날짜가 갖는 해당 주의 몇번째 요일
    func firstWeekdayOfMonth(in date: Date) -> Int {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        let firstDayOfMonth = Calendar.current.date(from: components) ?? date
        
        return Calendar.current.component(.weekday, from: firstDayOfMonth)
    }
    
    /// 월 변경
    func changeMonth(by value: Int) {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: value, to: month) {
            withAnimation{
                self.month = newMonth
            }
        }
    }
}

// MARK: - Static 프로퍼티
extension CalenderView {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy MMMM"
        return formatter
    }()
    
    static let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols
}
