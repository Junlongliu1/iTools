// 月视图组件，负责星期头和日期网格布局

import SwiftUI

struct MonthCalendarView: View {
    let date: Date
    @Binding var selectedDate: Date?
    
    private let calendar = Calendar.chinese
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    
    // 按月预计算的数据缓存
    @State private var monthInfo: [Date: ChineseCalendarInfo] = [:]
    @State private var isLoading = false
    
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
            
            // 日期网格
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
                            info: monthInfo[d],          // 直接传递缓存信息
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
        .task(id: date) {
            await loadMonthData()
        }
    }
    
    // MARK: - 异步加载该月所有日期信息
    private func loadMonthData() async {
        guard !isLoading else { return }
        isLoading = true
        
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else {
            isLoading = false
            return
        }
        
        // 调用服务批量获取
        let data = await ChineseCalendarService.shared.getMonthInfo(year: year, month: month)
        
        // 更新 UI
        await MainActor.run {
            self.monthInfo = data
            self.isLoading = false
        }
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
