// 主容器视图，管理月份状态、TabView 翻页和双向同步逻辑

import SwiftUI
import Tyme4Swift

struct ChineseCalendarView: View {
    @State private var currentMonth: Date = Date()
    @State private var selectedTabIndex: Int = 50
    @State private var selectedDate: Date?
    @State private var detailInfo: ChineseCalendarInfo?
    @State private var isWeekMode: Bool = false

    @GestureState private var dragOffset: CGFloat = 0
    
    private let calendar = Calendar.chinese
    private let weekHeight: CGFloat = 88
    
    private var monthHeight: CGFloat {
        let rows = numberOfRows(for: currentMonth)
        return CGFloat(44 + rows * 56)
    }

    private var calendarDisplayHeight: CGFloat {
        let base = isWeekMode ? weekHeight : monthHeight

        let target = isWeekMode ? monthHeight : weekHeight
        let progress = min(max(-dragOffset / max(abs(target - base), 1), 0), 1)
        
        if isWeekMode {
            return weekHeight + (monthHeight - weekHeight) * progress
        } else {
            return monthHeight - (monthHeight - weekHeight) * progress
        }
    }
    
    private var bottomContentOffset: CGFloat {
        if isWeekMode { return 0 }
        let maxShift = monthHeight - weekHeight
        return max(dragOffset, -maxShift)
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
                    }
                    .frame(height: calendarDisplayHeight, alignment: .top)
                    .clipped()
                    // 仅在非拖拽状态下响应状态变化的动画
                    .animation(dragOffset == 0 ? .easeInOut(duration: 0.3) : nil, value: isWeekMode)
                    .animation(dragOffset == 0 ? .easeInOut(duration: 0.25) : nil, value: currentMonth)
                    
                    Divider()
                        .padding(.top, 4)
                    
                    VStack(spacing: 0) {
                        HStack {
                            Rectangle()
                                .fill(Color(.systemGray4))
                                .frame(width: 36, height: 4)
                                .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        
                        Group {
                            if let info = detailInfo {
                                DateDetailView(info: info)
                                    .padding(.top, 8)
                            } else {
                                Color.clear.frame(height: 100)
                            }
                        }
                    }
                    .offset(y: bottomContentOffset)
                    .animation(dragOffset == 0 ? .easeInOut(duration: 0.3) : nil, value: isWeekMode)
                    
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            let vertical = value.translation.height
                            let horizontal = abs(value.translation.width)
                            
                            guard abs(vertical) > horizontal else { return }
                            
                            let threshold: CGFloat = 50
                            
                            if !isWeekMode && vertical < -threshold {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isWeekMode = true
                                }
                            } else if isWeekMode && vertical > threshold {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isWeekMode = false
                                }
                            }
                        },
                    including: isWeekMode ? .all : .all
                )
                
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
