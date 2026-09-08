// 主容器视图，管理月份状态、TabView 翻页和双向同步逻辑

import SwiftUI
import Tyme4Swift

struct ChineseCalendarView: View {
    @State private var currentMonth: Date = Date()
    // ✅ 初始偏移量设为一个较大的中间值，预留左右滑动空间
    @State private var selectedTabIndex: Int = 50
    
    private let calendar = Calendar.current
    private let calendarHeight: CGFloat = 304
    
    // ✅ 基准日期固定为 App 启动时的月初
    private let anchorDate: Date = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }()
    
    // ✅ 动态生成足够大的月份范围（前后各50个月 ≈ 8年）
    // 实际使用中几乎不可能滑到边界
    private let visibleRange: Range<Int> = -50..<51
    
    private func dateForIndex(_ index: Int) -> Date {
        let offset = index - 50
        return calendar.date(byAdding: .month, value: offset, to: anchorDate) ?? anchorDate
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CalendarHeader(date: $currentMonth)
                
                Divider()
                
                TabView(selection: $selectedTabIndex) {
                    ForEach(visibleRange, id: \.self) { index in
                        MonthCalendarView(date: dateForIndex(index))
                            .tag(index)
                            .id(index) // ✅ 用整数索引作为ID，比时间戳更高效稳定
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
                            selectedTabIndex = 50
                        }
                    }
                    .fontWeight(.medium)
                }
            }
            // ✅ 单向驱动：index → date
            .onChange(of: selectedTabIndex) { _, newIndex in
                let newDate = dateForIndex(newIndex)
                if !calendar.isDate(newDate, equalTo: currentMonth, toGranularity: .month) {
                    currentMonth = newDate
                }
            }
            // ✅ 反向同步：date → index（仅外部修改时触发）
            .onChange(of: currentMonth) { oldValue, newValue in
                guard !calendar.isDate(oldValue, equalTo: newValue, toGranularity: .month) else { return }
                
                let monthsDiff = calendar.dateComponents([.month], from: anchorDate, to: newValue).month ?? 0
                let targetIndex = 50 + monthsDiff
                
                if visibleRange.contains(targetIndex) && targetIndex != selectedTabIndex {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTabIndex = targetIndex
                    }
                }
            }
        }
    }
}
    
#Preview {
    ChineseCalendarView()
}
