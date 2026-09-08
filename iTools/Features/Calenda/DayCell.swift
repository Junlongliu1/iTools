// 日期单元格组件，负责单日渲染和数据懒加载

import SwiftUI

struct DayCell: View {
    let date: Date
    let currentDate: Date
    let isHighlighted: Bool
    let onTap: () -> Void
    
    @State private var info: ChineseCalendarInfo?
    
    private let calendar = Calendar.chinese
    private let service = ChineseCalendarService.shared
    
    private var isCurrentMonth: Bool {
        calendar.isDate(date, equalTo: currentDate, toGranularity: .month)
    }
    
    // 添加计算属性，替代原来的 info.subtitle
    private var subtitle: String {
        info?.holiday ?? ""
    }
    
    // 添加计算属性，替代原来的 info.subtitleColor
    private var subtitleColor: Color {
        if let holiday = info?.holiday, !holiday.isEmpty {
            return .red
        }
        return .secondary
    }
    
    var body: some View {
        ZStack {
            backgroundShape
            
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isHighlighted ? .bold : .regular, design: .rounded))
                    .monospacedDigit()
                
                Text(subtitle) // 使用新计算属性
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(isHighlighted ? .white.opacity(0.9) : subtitleColor) // 使用新计算属性
                    .frame(height: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if let info {
                switch info.workRestStatus {
                case .rest:
                    badgeText("休", color: .green)
                case .work:
                    badgeText("班", color: .red)
                case .none:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .foregroundStyle(foregroundColor)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .task(id: date) {
            info = service.getInfo(for: date)  // 移除了 info = nil，避免闪烁
        }
    }
    
    @ViewBuilder
    private func badgeText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(isHighlighted ? .white : color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                isHighlighted ? Color.white.opacity(0.25) : Color.clear,
                in: RoundedRectangle(cornerRadius: 3)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(4)
    }
    
    @ViewBuilder
    private var backgroundShape: some View {
        if isHighlighted {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red)
        } else {
            Color.clear
        }
    }
    
    private var foregroundColor: Color {
        if isHighlighted { return .white }
        if !isCurrentMonth { return .secondary.opacity(0.3) }
        return .primary
    }
}
