// 月视图组件，负责星期头和日期网格布局

import SwiftUI

struct MonthCalendarView: View {
    let date: Date
    @Binding var selectedDate: Date?
    
    private let calendar = Calendar.chinese
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    
    var body: some View {
        VStack(spacing: 0) {
            // 星期头：固定高度，周六日红色
            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, day in
                    Text(day)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(index >= 5 ? Color.red : Color.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 32)
            .padding(.bottom, 4)
            
            // 日期网格：无分割线，统一高亮
            LazyVGrid(columns: weekColumns, spacing: 4) {
                ForEach(daysInMonth, id: \.self) { d in
                    if let d {
                        let isHighlighted: Bool = {
                            if let selected = selectedDate {
                                return calendar.isDate(d, inSameDayAs: selected)
                            } else {
                                return calendar.isDateInToday(d)
                            }
                        }()
                        
                        DayCell(
                            date: d,
                            currentDate: date,
                            isHighlighted: isHighlighted,
                            onTap: { selectedDate = d }
                        )
                    } else {
                        Color.clear.frame(minHeight: 52)
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
        let days = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: firstDay) }
        let trailingBlanksCount = 42 - leadingBlanksCount - days.count
        let trailingBlanks = Array(repeating: Optional<Date>.none, count: trailingBlanksCount)
        return leadingBlanks + days.map { Optional($0) } + trailingBlanks
    }
}
