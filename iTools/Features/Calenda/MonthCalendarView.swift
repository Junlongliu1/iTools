// 月视图组件，负责星期头和日期网格布局

import SwiftUI

struct MonthCalendarView: View {
    let date: Date
    
    private let calendar = Calendar.current
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    private let rowSpacing: CGFloat = 4
    
    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: weekColumns, spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(height: 28)
                }
            }
            .padding(.bottom, rowSpacing)
            
            LazyVGrid(columns: weekColumns, spacing: rowSpacing) {
                ForEach(daysInMonth, id: \.self) { d in
                    if let d {
                        DayCell(date: d, currentDate: date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var weekColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    }
    
    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return Array(repeating: nil, count: 42)
        }
        
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingBlanksCount = (weekday == 1) ? 6 : (weekday - 2)
        
        let leadingBlanks = Array(repeating: Optional<Date>.none, count: leadingBlanksCount)
        let days = range.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: firstDay)
        }
        let trailingBlanksCount = 42 - leadingBlanksCount - days.count
        let trailingBlanks = Array(repeating: Optional<Date>.none, count: trailingBlanksCount)
        
        return leadingBlanks + days.map { Optional($0) } + trailingBlanks
    }
}
