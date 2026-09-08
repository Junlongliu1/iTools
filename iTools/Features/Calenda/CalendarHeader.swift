// 头部组件，独立管理月份标题和切换按钮

import SwiftUI

// 结构体名保持不变
struct CalendarHeader: View {
    let date: Date
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(yearText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .opacity(0.6)
            
            Text(monthText)
                .font(.system(size: 28, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var yearText: String {
        "\(calendar.component(.year, from: date))年"
    }
    
    private var monthText: String {
        "\(calendar.component(.month, from: date))月"
    }
}

#Preview {
    ChineseCalendarView()
}
