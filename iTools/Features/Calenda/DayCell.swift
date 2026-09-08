// 日期单元格组件，负责单日渲染和数据懒加载

import SwiftUI

struct DayCell: View {
    let date: Date
    let currentDate: Date
    let isHighlighted: Bool
    let onTap: () -> Void
    
    @State private var info: ChineseCalendarInfo?
    
    private let calendar = Calendar.current
    private let service = ChineseCalendarService.shared
    
    private var isCurrentMonth: Bool {
        calendar.isDate(date, equalTo: currentDate, toGranularity: .month)
    }
    
    var body: some View {
        ZStack {
            // 背景层：统一使用红色圆角矩形
            backgroundShape
            
            // 内容层：日期 + 副标题
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isHighlighted ? .bold : .regular, design: .rounded))
                    .monospacedDigit()
                
                if let info {
                    Text(info.subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(isHighlighted ? .white.opacity(0.9) : info.subtitleColor)
                        .frame(height: 12)
                } else {
                    Color.clear.frame(height: 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 角标层：固定在右上角
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
            info = nil
            info = service.getInfo(for: date)
        }
    }
    
    // 角标视图
    @ViewBuilder
    private func badgeText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            // 高亮时角标变白，否则显示原色
            .foregroundStyle(isHighlighted ? .white : color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                // 高亮时给个半透明白底，非高亮时透明
                isHighlighted ? Color.white.opacity(0.25) : Color.clear,
                in: RoundedRectangle(cornerRadius: 3)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(4)
    }
    
    // 背景形状：统一为红色圆角矩形
    @ViewBuilder
    private var backgroundShape: some View {
        if isHighlighted {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red)
        } else {
            Color.clear
        }
    }
    
    //  文字颜色逻辑
    private var foregroundColor: Color {
        if isHighlighted { return .white }           // 高亮时全白
        if !isCurrentMonth { return .secondary.opacity(0.3) } // 非当月灰色
        return .primary                              // 普通工作日黑色
    }
}
