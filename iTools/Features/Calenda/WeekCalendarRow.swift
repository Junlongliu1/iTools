// 周视图行

import SwiftUI

struct WeekCalendarRow: View {
    let dates: [Date]
    @Binding var selectedDate: Date?
    let currentMonth: Date
    
    private let calendar = Calendar.chinese
    
    var body: some View {
        VStack(spacing: 0) {
            // 星期头
            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, day in
                    Text(day)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(index >= 5 ? Color.red : Color.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 28)
            
            // 日期行
            HStack(spacing: 0) {
                ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate ?? .distantPast)
                    
                    DayCell(
                        date: date,
                        currentDate: currentMonth,
                        isHighlighted: isSelected,
                        info: ChineseCalendarService.shared.getInfo(for: date)
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDate = date
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
}
