// 主容器视图，管理月份状态、TabView 翻页和双向同步逻辑

// MARK: - ChineseCalendarView.swift（彻底修复滑动与折叠）

import SwiftUI
import Tyme4Swift

struct ChineseCalendarView: View {
    @State private var currentMonth: Date = Date()
    @State private var selectedTabIndex: Int = 50
    @State private var selectedDate: Date?
    @State private var detailInfo: ChineseCalendarInfo?
    @State private var isWeekMode: Bool = false
    
    private let calendar = Calendar.chinese
    private let weekHeight: CGFloat = 88
    
    private var monthHeight: CGFloat {
        let rows = numberOfRows(for: currentMonth)
        return CGFloat(44 + rows * 56)
    }
    
    private let anchorDate: Date = {
        Calendar.chinese.date(from: DateComponents(year: 2024, month: 1)) ?? Date()
    }()
    
    private let visibleRange: Range<Int> = 0..<101
    
    private func dateForIndex(_ index: Int) -> Date {
        let offset = index - 50
        return calendar.date(byAdding: .month, value: offset, to: anchorDate) ?? anchorDate
    }
    
    private func indexForDate(_ date: Date) -> Int {
        let monthsDiff = calendar.dateComponents([.month], from: anchorDate, to: date).month ?? 0
        return max(0, min(100, 50 + monthsDiff))
    }
    
    private func numberOfRows(for date: Date) -> Int {
        guard let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let dayCount = calendar.range(of: .day, in: .month, for: date)?.count else {
            return 6
        }
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingBlanks = (weekday == 1) ? 6 : (weekday - 2)
        let totalCells = leadingBlanks + dayCount
        return totalCells > 35 ? 6 : 5
    }
    
    private var weekOfSelectedDate: [Date] {
        guard let date = selectedDate else { return [] }
        let weekday = calendar.component(.weekday, from: date)
        let mondayOffset = (weekday == 1) ? -6 : -(weekday - 2)
        let weekStart = calendar.date(byAdding: .day, value: mondayOffset, to: date) ?? date
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    CalendarHeader(date: currentMonth)
                        .foregroundStyle(.red)
                    
                    Divider()

                    VStack(spacing: 0) {
                        Group {
                            if isWeekMode {
                                WeekCalendarRow(
                                    dates: weekOfSelectedDate,
                                    selectedDate: $selectedDate,
                                    currentMonth: currentMonth
                                )
                                .frame(height: weekHeight)
                            } else {
                                TabView(selection: $selectedTabIndex) {
                                    ForEach(visibleRange, id: \.self) { index in
                                        MonthCalendarView(
                                            date: dateForIndex(index),
                                            selectedDate: $selectedDate,
                                            onWeekSwitch: {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    isWeekMode = true
                                                }
                                            }
                                        )
                                        .tag(index)
                                        .id(index)
                                    }
                                }
                                .tabViewStyle(.page(indexDisplayMode: .never))
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    // 动态高度
                    .frame(height: isWeekMode ? weekHeight : monthHeight, alignment: .top)
                    .clipped()
                    .animation(.easeInOut(duration: 0.3), value: isWeekMode)
                    .animation(.easeInOut(duration: 0.25), value: currentMonth)
                    
                    Divider()
                        .padding(.top, 4)
                    
                    // 横条指示器：增加拖拽手势支持上拉
                    HStack {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(width: 36, height: 4)
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onEnded { value in
                                // 上拉超过 30pt 且垂直主导 → 切换到周视图
                                if value.translation.height < -30 &&
                                   abs(value.translation.height) > abs(value.translation.width) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isWeekMode = true
                                    }
                                }
                                // 下拉超过 30pt 且垂直主导 → 切换到月视图
                                else if value.translation.height > 30 &&
                                        abs(value.translation.height) > abs(value.translation.width) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isWeekMode = false
                                    }
                                }
                            }
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) { isWeekMode.toggle() }
                    }
                    
                    // 详情卡片
                    Group {
                        if let info = detailInfo {
                            DateDetailView(info: info)
                                .padding(.top, 8)
                        } else {
                            Color.clear.frame(height: 100)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: detailInfo)
                    
                    Spacer(minLength: 0)
                }
                
                // "今"按钮
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentMonth = Date()
                        selectedTabIndex = indexForDate(Date())
                        selectedDate = Date()
                        isWeekMode = false
                    }
                } label: {
                    Text("今")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.red, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .task(id: selectedDate) {
                guard let date = selectedDate else {
                    detailInfo = nil
                    return
                }
                detailInfo = ChineseCalendarService.shared.getInfo(for: date)
            }
            .onChange(of: selectedTabIndex) { _, newIndex in
                let newDate = dateForIndex(newIndex)
                if !calendar.isDate(newDate, equalTo: currentMonth, toGranularity: .month) {
                    currentMonth = newDate
                }
            }
            .onChange(of: currentMonth) { oldValue, newValue in
                guard !calendar.isDate(oldValue, equalTo: newValue, toGranularity: .month) else { return }
                let targetIndex = indexForDate(newValue)
                if targetIndex != selectedTabIndex {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTabIndex = targetIndex
                    }
                }
            }
        }
        .onAppear {
            let initialIndex = indexForDate(currentMonth)
            if initialIndex != selectedTabIndex {
                selectedTabIndex = initialIndex
            }
            if selectedDate == nil {
                selectedDate = Date()
            }
        }
    }
}

#Preview {
    ChineseCalendarView()
}
