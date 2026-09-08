// 月视图组件，负责星期头和日期网格布局

import SwiftUI

struct MonthCalendarView: View {
    let date: Date
    @Binding var selectedDate: Date?
    var onWeekSwitch: (() -> Void)? = nil
    
    private let calendar = Calendar.chinese
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    
    @State private var monthInfo: [Date: ChineseCalendarInfo] = [:]
    @State private var isLoading = false
    
    @GestureState private var dragOffset: CGFloat = 0
    
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
            .frame(height: 32)
            .padding(.bottom, 4)
            
            LazyVGrid(columns: weekColumns, spacing: 4) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, d in
                    let isHighlighted: Bool = {
                        if let selected = selectedDate {
                            return calendar.isDate(d, inSameDayAs: selected)
                        } else {
                            return calendar.isDateInToday(d)
                        }
                    }()
                    
                    DayCell(
                        date: d,
                        currentDate: self.date,
                        isHighlighted: isHighlighted,
                        info: monthInfo[d],
                        onTap: { selectedDate = d }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .task(id: date) {
            await loadMonthData()
        }
    }
    
    // MARK: - 异步加载当月 + 补全日期的数据
    private func loadMonthData() async {
        guard !isLoading else { return }
        isLoading = true
        
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else {
            isLoading = false
            return
        }
        
        let data = await ChineseCalendarService.shared.getMonthInfo(year: year, month: month)
        
        let gridDates = daysInMonth
        let extraDates = gridDates.filter { !calendar.isDate($0, equalTo: date, toGranularity: .month) }
        
        var extraInfo: [Date: ChineseCalendarInfo] = [:]
        for d in extraDates {
            extraInfo[d] = ChineseCalendarService.shared.getInfo(for: d)
        }
        
        await MainActor.run {
            self.monthInfo = data.merging(extraInfo) { _, new in new }
            self.isLoading = false
        }
    }
    
    private var weekColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    }
    
    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return []
        }
        
        let weekday = calendar.component(.weekday, from: firstDay) // 1=周日
        let leadingBlanksCount = (weekday == 1) ? 6 : (weekday - 2) // 周一为起始
        
        // 上月补全（仅补齐第一行）
        let leadingDates: [Date] = (1...max(leadingBlanksCount, 1)).reversed().compactMap {
            leadingBlanksCount > 0 ? calendar.date(byAdding: .day, value: -$0, to: firstDay) : nil
        }
        
        // 当月所有日期
        let days: [Date] = range.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: firstDay)
        }
        
        let totalSoFar = leadingDates.count + days.count
        let remainder = totalSoFar % 7
        let trailingCount = remainder == 0 ? 0 : (7 - remainder)
        
        let lastDay = days.last ?? firstDay
        let trailingDates: [Date] = (1...max(trailingCount, 1)).compactMap {
            trailingCount > 0 ? calendar.date(byAdding: .day, value: $0, to: lastDay) : nil
        }
        
        return leadingDates + days + trailingDates
    }
}
