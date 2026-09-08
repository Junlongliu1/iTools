// 日期单元格组件，负责单日渲染和数据懒加载

import SwiftUI

struct DayCell: View {
    let date: Date
    let currentDate: Date
    let isHighlighted: Bool
    let info: ChineseCalendarInfo?
    let onTap: () -> Void
    
    private let calendar = Calendar.chinese
    
    private var isCurrentMonth: Bool {
        calendar.isDate(date, equalTo: currentDate, toGranularity: .month)
    }
    
    var body: some View {
        ZStack {
            backgroundShape
            
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isHighlighted ? .bold : .regular, design: .rounded))
                    .monospacedDigit()
                
                // 副标题显示：优先级 节日 > 节气 > 农历
                Text(info?.subtitle ?? "")
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(isHighlighted ? .white.opacity(0.9) : (info?.subtitleColor ?? .secondary))
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
