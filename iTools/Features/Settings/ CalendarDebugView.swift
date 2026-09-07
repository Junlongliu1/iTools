import SwiftUI


struct CalendarDayItem: Identifiable {
    let id: String
    let date: String
    let nameCN: String
    let nameEN: String
    let duration: Int
    let type: DayType
    
    enum DayType: String, CaseIterable {
        case holiday, inLieu, workday
        
        var label: String {
            switch self {
            case .holiday: return "休"
            case .inLieu:  return "调"
            case .workday: return "班"
            }
        }
        
        var color: Color {
            switch self {
            case .holiday: return .green
            case .inLieu:  return .blue
            case .workday: return .orange
            }
        }
    }
}

struct CalendarDebugView: View {
    @State private var yearlyData: [Int: [CalendarDayItem]] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
    private var availableYears: [Int] {
        yearlyData.keys.sorted().reversed()
    }
    
    // 当前选中年份的月份分组
    private var currentMonthlyGroups: [MonthlyGroup] {
        guard let items = yearlyData[selectedYear] else { return [] }
        return groupByMonth(items)
    }
    
    var body: some View {
        Group {
            if isLoading {
                ContentUnavailableView {
                    ProgressView().scaleEffect(1.2)
                } description: {
                    Text("正在读取本地缓存...").foregroundStyle(.secondary)
                }
            } else if let error = errorMessage {
                ContentUnavailableView(error, systemImage: "exclamationmark.triangle.fill")
            } else if yearlyData.isEmpty {
                ContentUnavailableView(
                    "暂无缓存数据", systemImage: "tray.fill",
                    description: Text("请先打开主日历页面触发数据加载")
                )
            } else {
                VStack(spacing: 0) {
                    yearPicker
                    
                    Divider()
                    
                    // 下方仅展示选中年份的月份数据
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(currentMonthlyGroups, id: \.month) { group in
                                MonthSubsection(group: group)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .navigationTitle("节假日数据")
        .task { await loadCachedData() }
        // 当选中年份变化时，确保该年份存在于数据中
        .onChange(of: selectedYear) { _, newValue in
            if !yearlyData.keys.contains(newValue), let fallback = availableYears.first {
                selectedYear = fallback
            }
        }
    }
    
    // MARK: - 年份选择器
    
    private var yearPicker: some View {
        HStack(spacing: 12) {
            Text("年份")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Picker("选择年份", selection: $selectedYear) {
                ForEach(availableYears, id: \.self) { year in
                    Text("\(year)").tag(year)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - 月份子分组（保持不变）
    
    private struct MonthSubsection: View {
        let group: MonthlyGroup
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("\(group.month)月")
                        .font(.caption.bold())
                    
                    Spacer()
                    
                    ForEach(CalendarDayItem.DayType.allCases, id: \.self) { type in
                        let count = group.items.filter({ $0.type == type }).count
                        if count > 0 {
                            MiniStatBadge(text: "\(type.label)\(count)", color: type.color)
                        }
                    }
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                    ForEach(group.items) { item in
                        DayCell(item: item)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
    
    // MARK: - 单日卡片（保持不变）
    
    private struct DayCell: View {
        let item: CalendarDayItem
        
        private var dayNumber: String {
            String(item.date.suffix(2))
        }
        
        var body: some View {
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.primary)
                
                Text(item.type.label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(item.type.color, in: Circle())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(item.type.color.opacity(0.1))
            )
            .contextMenu {
                Label("\(item.nameCN)", systemImage: "tag.fill")
                Label("\(item.nameEN)", systemImage: "globe")
                Label("持续 \(item.duration) 天", systemImage: "clock")
            }
        }
    }
    
    // MARK: - 辅助组件（保持不变）
    
    private struct MiniStatBadge: View {
        let text: String
        let color: Color
        
        var body: some View {
            Text(text)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(color.opacity(0.12), in: Capsule())
        }
    }
    
    // MARK: - 数据处理（保持不变）
    
    private struct MonthlyGroup {
        let month: Int
        let items: [CalendarDayItem]
    }
    
    private func groupByMonth(_ items: [CalendarDayItem]) -> [MonthlyGroup] {
        let grouped = Dictionary(grouping: items) { item -> Int in
            guard item.date.count >= 6 else { return 0 }
            return Int(item.date.dropFirst(5).prefix(2)) ?? 0
        }
        return grouped.map { MonthlyGroup(month: $0.key, items: $0.value.sorted(by: { $0.date < $1.date })) }
            .sorted(by: { $0.month < $1.month })
    }
    
    private func loadCachedData() async {
        let cacheFileName = "chinese_days_full.json"
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(cacheFileName)
        
        guard let data = try? Data(contentsOf: cacheURL) else {
            errorMessage = "未找到缓存文件\n路径: \(cacheURL.path)"
            isLoading = false
            return
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: String]] else {
                errorMessage = "JSON 顶层结构不匹配\n期望: {holidays, inLieuDays, workdays}"
                isLoading = false
                return
            }
            
            var allItems: [CalendarDayItem] = []
            
            let typeMapping: [(key: String, type: CalendarDayItem.DayType)] = [
                ("holidays",   .holiday),
                ("inLieuDays", .inLieu),
                ("workdays",   .workday)
            ]
            
            for mapping in typeMapping {
                guard let dict = json[mapping.key] else { continue }
                for (dateStr, csvValue) in dict {
                    let parts = csvValue.components(separatedBy: ",")
                    let nameEN = parts[safe: 0] ?? ""
                    let nameCN = parts[safe: 1] ?? ""
                    let duration = Int(parts[safe: 2] ?? "") ?? 1
                    
                    allItems.append(CalendarDayItem(
                        id: "\(dateStr)-\(mapping.type.rawValue)",
                        date: dateStr,
                        nameCN: nameCN,
                        nameEN: nameEN,
                        duration: duration,
                        type: mapping.type
                    ))
                }
            }
            
            var grouped: [Int: [CalendarDayItem]] = [:]
            for item in allItems {
                let year = Int(item.date.prefix(4)) ?? 0
                grouped[year, default: []].append(item)
            }
            
            for key in grouped.keys {
                grouped[key]?.sort(by: { $0.date < $1.date })
            }
            
            yearlyData = grouped
            
            // 加载完成后，若当前选中年份无数据则自动回退到最新年份
            if !grouped.keys.contains(selectedYear), let latest = grouped.keys.max() {
                selectedYear = latest
            }
        } catch {
            errorMessage = "JSON 解析失败:\n\(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

// 安全数组访问扩展
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
