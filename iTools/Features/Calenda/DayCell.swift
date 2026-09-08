// 日期单元格组件，负责单日渲染和数据懒加载

import SwiftUI

struct DayCell: View {
    let date: Date
    let currentDate: Date
    
    @State private var info: ChineseCalendarInfo?
    
    private let calendar = Calendar.current
    private let service = ChineseCalendarService.shared
    
    private var isToday: Bool { calendar.isDateInToday(date) }
    private var isCurrentMonth: Bool {
        calendar.isDate(date, equalTo: currentDate, toGranularity: .month)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16, weight: isToday ? .bold : .regular, design: .rounded))
                .monospacedDigit()
            
            if let info {
                Text(info.subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(info.subtitleColor)
                    .frame(height: 14)
            } else {
                Color.clear.frame(height: 14)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(backgroundShape)
        .foregroundStyle(foregroundColor)
        .task(id: date) {
            info = nil
            info = service.getInfo(for: date)
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
        if let info, info.isOffDay { return .red }
        return .primary
    }
}
