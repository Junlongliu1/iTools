import SwiftUI

// MARK: - 主视图容器
struct ChineseCalendarView: View {
    @State private var currentMonth: Date = Date()
    @StateObject private var holidayProvider = HolidayManager.shared
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CalendarHeader(date: $currentMonth)
                
                Divider()
                
                // ✅ 修复：不再使用 GeometryReader，让 TabView 内的月视图自适应高度
                TabView(selection: $currentMonth) {
                    ForEach(monthRange, id: \.self) { monthDate in
                        MonthCalendarView(
                            date: monthDate,
                            provider: holidayProvider
                        )
                        .tag(monthDate)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: currentMonth)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("今天") {
                        withAnimation(.spring(response: 0.3)) {
                            currentMonth = Date()
                        }
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }
    
    private var monthRange: [Date] {
        (-6...6).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: currentMonth)
        }
    }
}

// MARK: - 头部导航组件
struct CalendarHeader: View {
    @Binding var date: Date
    
    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年"
        return f
    }()
    
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月"
        return f
    }()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.yearFormatter.string(from: date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(Self.monthFormatter.string(from: date))
                    .font(.title2.bold())
                    .contentTransition(.numericText())
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - 月视图（周一为起始日）
struct MonthCalendarView: View {
    let date: Date
    let provider: HolidayDataProvider?
    
    private let calendar = Calendar.current
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    
    // ✅ 修复：统一定义所有行间距为同一个值
    private let rowSpacing: CGFloat = 4
    
    var body: some View {
        // ✅ 修复：顶部对齐 + Spacer 推底，不再撑满父容器高度
        VStack(spacing: 0) {
            // 星期标题行
            LazyVGrid(columns: weekColumns, spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(height: 28)
                }
            }
            // ✅ 修复：标题与第一行日期的间距 = rowSpacing
            .padding(.bottom, rowSpacing)
            
            // 日期网格
            LazyVGrid(columns: weekColumns, spacing: rowSpacing) {
                ForEach(daysInMonth, id: \.self) { d in
                    if let d {
                        DayCell(date: d, currentDate: date, provider: provider)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
            
            // ✅ 修复：将多余空间推到底部，保证上方网格紧凑且间距一致
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private var weekColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    }
    
    /// 以周一为起始日计算当月所有格子（固定42格 = 6行×7列）
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

// MARK: - 日期单元格
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
