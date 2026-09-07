import SwiftUI

// MARK: - 主视图容器
struct ChineseCalendarView: View {
    @State private var currentMonth: Date = Date()
    @StateObject private var holidayProvider = HolidayManager.shared
    
    private let calendar = Calendar.current
    private let calendarHeight: CGFloat = 304

    @State private var selectedTabIndex: Int = 6
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CalendarHeader(date: $currentMonth)
                
                Divider()

                TabView(selection: $selectedTabIndex) {
                    ForEach(monthRange.indices, id: \.self) { index in
                        MonthCalendarView(
                            date: monthRange[index],
                            provider: holidayProvider
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: calendarHeight)
                .animation(.easeInOut(duration: 0.25), value: selectedTabIndex)
                
                Spacer(minLength: 0)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("今天") {
                        withAnimation(.spring(response: 0.3)) {
                            currentMonth = Date()
                            selectedTabIndex = 6
                        }
                    }
                    .fontWeight(.medium)
                }
            }

            .onChange(of: selectedTabIndex) { _, newIndex in
                let offset = newIndex - 6
                if let newDate = calendar.date(byAdding: .month, value: offset, to: anchorDate) {
                    currentMonth = newDate
                }
            }
            .onChange(of: currentMonth) { _, newDate in
                let components = calendar.dateComponents([.year, .month], from: anchorDate)
                let newComponents = calendar.dateComponents([.year, .month], from: newDate)
                
                guard let anchorMonths = calendar.dateComponents([.month], from: components, to: newComponents).month else { return }
                let newIndex = 6 + anchorMonths
                
                if newIndex != selectedTabIndex && (0...12).contains(newIndex) {
                    selectedTabIndex = newIndex
                }
            }
        }
    }
    
    /// 锚点日期：始终为当前真实月份，用于计算偏移
    private var anchorDate: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
    }
    
    /// 生成以当前月为中心的 13 个月范围
    private var monthRange: [Date] {
        (-6...6).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: anchorDate)
        }
    }
}

// MARK: - 月视图 (移除所有外部 frame 约束，尺寸由 containerRelativeFrame 控制)
struct MonthCalendarView: View {
    let date: Date
    let provider: HolidayDataProvider?
    
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
                        DayCell(date: d, currentDate: date, provider: provider)
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
        let days = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: firstDay) }
        let trailingBlanksCount = 42 - leadingBlanksCount - days.count
        let trailingBlanks = Array(repeating: Optional<Date>.none, count: trailingBlanksCount)
        
        return leadingBlanks + days.map { Optional($0) } + trailingBlanks
    }
}

// MARK: - 日期单元格 (保持不变)
struct DayCell: View {
    let date: Date
    let currentDate: Date
    let provider: HolidayDataProvider?
    
    private let calendar = Calendar.current
    
    private var isToday: Bool { calendar.isDateInToday(date) }
    private var isCurrentMonth: Bool { calendar.isDate(date, equalTo: currentDate, toGranularity: .month) }
    private var holidayInfo: (name: String, isOffDay: Bool)? { provider?.getHolidayInfo(for: date) }
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16, weight: isToday ? .bold : .regular, design: .rounded))
                .monospacedDigit()
            
            holidayLabel
                .frame(height: 14)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(backgroundShape)
        .foregroundStyle(foregroundColor)
    }
    
    @ViewBuilder
    private var holidayLabel: some View {
        if let info = holidayInfo {
            Text(info.name)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(info.isOffDay ? .red : .orange)
        } else {
            Color.clear
        }
    }
    
    @ViewBuilder
    private var backgroundShape: some View {
        if isToday {
            Circle()
                .fill(Color.red)
                .padding(4)
        } else {
            Color.clear
        }
    }
    
    private var foregroundColor: Color {
        if isToday { return .white }
        if !isCurrentMonth { return .secondary.opacity(0.3) }
        if let info = holidayInfo, info.isOffDay { return .red }
        return .primary
    }
}
