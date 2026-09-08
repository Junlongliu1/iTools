// 主容器视图，管理月份状态、TabView 翻页和双向同步逻辑

import SwiftUI
import Tyme4Swift

struct ChineseCalendarView: View {
    @State private var currentMonth: Date = Date()
    @State private var selectedTabIndex: Int = 50
    @State private var selectedDate: Date?
    @State private var detailInfo: ChineseCalendarInfo?
    
    private let calendar = Calendar.chinese
    private let calendarHeight: CGFloat = 370
    
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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    CalendarHeader(date: currentMonth)
                        .foregroundStyle(.red)
                    
                    Divider()
                    
                    // 月历网格
                    TabView(selection: $selectedTabIndex) {
                        ForEach(visibleRange, id: \.self) { index in
                            MonthCalendarView(
                                date: dateForIndex(index),
                                selectedDate: $selectedDate
                            )
                            .tag(index)
                            .id(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: calendarHeight)
                    .animation(.easeInOut(duration: 0.25), value: selectedTabIndex)
                    
                    Group {
                        if let info = detailInfo {
                            DateDetailView(info: info)
                                .padding(.top, 12)
                        } else {
                            // 占位防止高度跳动
                            Color.clear.frame(height: 100)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: detailInfo)
                    
                    Spacer(minLength: 0)
                }
                
                // “今”按钮
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentMonth = Date()
                        selectedTabIndex = indexForDate(Date())
                        selectedDate = Date()
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

