// AnniversaryView.swift
import SwiftUI
import SwiftData
import UIKit
import Accessibility

// MARK: - 分类选中

enum CategorySelection: Hashable, Identifiable {
    case all
    case category(AnniversaryCategory)

    var id: String {
        switch self {
        case .all: return "all"
        case .category(let c): return c.rawValue
        }
    }

    var title: String {
        switch self {
        case .all: return "全部"
        case .category(let c): return c.title
        }
    }

    var symbol: String {
        switch self {
        case .all: return "square.stack.3d.up.fill"
        case .category(let c): return c.symbol
        }
    }

    var tint: Color {
        switch self {
        case .all: return Color(red: 0.36, green: 0.58, blue: 1.00)
        case .category(let c): return c.topColor
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: return "还没有任何纪念日"
        case .category(let c): return "暂无\(c.title)"
        }
    }

    static var allCases: [CategorySelection] {
        [.all] + AnniversaryCategory.allCases.map(CategorySelection.category)
    }
}

// MARK: - 主视图

struct AnniversaryView: View {
    @Query(sort: \Anniversary.date) private var all: [Anniversary]

    @State private var path = NavigationPath()

    @State private var showCreate = false
    @State private var showCloudSettings = false
    @State private var selectedCategory: CategorySelection = .all
    @State private var searchText = ""
    @State private var sortOrder: AnniversarySortOrder = .nextDate

    /// 仅用于「跨天刷新」：值变化会触发 body 重新求值。
    @State private var today = Calendar.current.startOfDay(for: Date())

    // MARK: 数据源

    private var displayAll: [Anniversary] { all }

    private var upcoming: [Anniversary] {
        displayAll
            .compactMap { item -> (Anniversary, Int)? in
                let d = item.daysUntil
                guard d >= 0 && d <= 30 else { return nil }
                return (item, d)
            }
            .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.createdAt < $1.0.createdAt }
            .prefix(6)
            .map(\.0)
    }

    private var recentPast: [Anniversary] {
        displayAll
            .compactMap { item -> (Anniversary, Int)? in
                guard let d = item.daysSinceLast, d >= 1 && d <= 30 else { return nil }
                return (item, d)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    private var selectedItems: [Anniversary] {
        let base: [Anniversary]
        switch selectedCategory {
        case .all:
            base = displayAll
        case .category(let c):
            base = displayAll.filter { $0.category == c }
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searched: [Anniversary]
        if q.isEmpty {
            searched = base
        } else {
            searched = base.filter {
                $0.title.localizedStandardContains(q)
                || $0.notes.localizedStandardContains(q)
            }
        }
        return sortOrder.sorted(searched)
    }

    // MARK: body

    var body: some View {
        NavigationStack(path: $path) {
            List {
                upcomingSection
                recentPastSection
                filterSection
                footerSection
            }
            .listStyle(.plain)
            .listRowSpacing(6)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.hard, for: .bottom)
            .contentMargins(.top, 4, for: .scrollContent)
            .contentMargins(.bottom, 120, for: .scrollContent)
            .navigationTitle("纪念日")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索名称或备注")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showCloudSettings = true
                    } label: {
                        Image(systemName: "externaldrive.badge.icloud")
                    }
                    .accessibilityLabel("云盘备份")

                    sortMenu
                }
            }
            .navigationDestination(for: Anniversary.self) { item in
                AnniversaryDetailView(anniversary: item)
            }
            .sheet(isPresented: $showCreate) {
                AnniversaryEditor(mode: .create)
            }
            .sheet(isPresented: $showCloudSettings) {
                NavigationStack { CloudBackupView() }
            }
            .overlay(alignment: .bottomTrailing) {
                GlassEffectContainer(spacing: 16) {
                    addButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                }
            }
        }
        // 跨天刷新：60 秒轮询，日期变化才触发重渲染
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if Task.isCancelled { return }
                let t = Calendar.current.startOfDay(for: Date())
                if t != today { today = t }
            }
        }
    }

    // MARK: Section 1 · 即将到来

    @ViewBuilder
    private var upcomingSection: some View {
        if !upcoming.isEmpty {
            Section {
                ForEach(upcoming) { item in
                    Button {
                        path.append(item)
                    } label: {
                        UpcomingGlassCard(anniversary: item)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } header: {
                sectionHeader(
                    title: "即将到来",
                    trailing: "30 天内 \(upcoming.count) 个"
                )
            }
        }
    }

    // MARK: Section 2 · 刚刚过去

    @ViewBuilder
    private var recentPastSection: some View {
        if !recentPast.isEmpty {
            Section {
                ForEach(recentPast) { item in
                    Button {
                        path.append(item)
                    } label: {
                        PastRow(anniversary: item)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 2)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(.init(top: 3, leading: 16, bottom: 3, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } header: {
                sectionHeader(
                    title: "刚刚过去",
                    trailing: "30 天内 \(recentPast.count) 个"
                )
            }
        }
    }

    // MARK: Section 3 · 筛选 + 列表

    @ViewBuilder
    private var filterSection: some View {
        Section {
            categoryPicker
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
                .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if selectedItems.isEmpty {
                emptyInline
                    .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(selectedItems) { item in
                    Button {
                        path.append(item)
                    } label: {
                        AnniversaryRow(anniversary: item)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 2)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(.init(top: 3, leading: 16, bottom: 3, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        } header: {
            EmptyView()
        }
    }

    // MARK: Section 4 · 空白 footer

    private var footerSection: some View {
        Section {
            Color.clear
                .frame(height: 1)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    // MARK: Section 头部

    private func sectionHeader(title: String, trailing: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
                .textCase(nil)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    // MARK: 空状态

    private var emptyInline: some View {
        VStack(spacing: 8) {
            Image(systemName: selectedCategory.symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary.opacity(0.6))

            Text(searchText.isEmpty
                 ? selectedCategory.emptyTitle
                 : "没有匹配「\(searchText)」的纪念日")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: 分类 Picker

    private var categoryPicker: some View {
        Picker("分类", selection: $selectedCategory) {
            ForEach(CategorySelection.allCases) { sel in
                Text(sel.title).tag(sel)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedCategory) { _, _ in
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    // MARK: 排序菜单

    private var sortMenu: some View {
        Menu {
            Picker("排序", selection: $sortOrder) {
                ForEach(AnniversarySortOrder.allCases) { order in
                    Label(order.title, systemImage: order.symbol).tag(order)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
        .accessibilityLabel("排序方式")
    }

    // MARK: 浮动 +

    private var addButton: some View {
        Button {
            showCreate = true
        } label: {
            Label("添加", systemImage: "plus")
                .labelStyle(.iconOnly)
                .font(.system(size: 22, weight: .semibold))
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .controlSize(.extraLarge)
        .tint(.pink)
    }
}

// MARK: - 即将到来：液态玻璃卡片

struct UpcomingGlassCard: View {
    let anniversary: Anniversary

    var body: some View {
        cardContent
    }

    private var cardContent: some View {
        HStack(spacing: 14) {
            dateBadge

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    if anniversary.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.orange)
                            .rotationEffect(.degrees(45))
                    }
                    Text(anniversary.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Image(systemName: anniversary.category.symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(anniversary.category.topColor)

                    if let lunar = anniversary.lunarDateText {
                        Text("农历\(lunar)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Text("· \(anniversary.gregorianDateText)")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(anniversary.gregorianDateText)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    if anniversary.isYearly && anniversary.yearsCount > 0 {
                        Text("· \(anniversary.yearsCount) 周年")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 8)

            countdown
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(cardGlass, in: .rect(cornerRadius: 22))
    }

    private var cardGlass: Glass {
        var g: Glass = .regular.interactive()
        if anniversary.isToday {
            g = g.tint(anniversary.category.topColor.opacity(0.22))
        }
        return g
    }

    private var dateBadge: some View {
        VStack(spacing: 1) {
            Text(monthText)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text(dayText)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(width: 50, height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            anniversary.category.topColor,
                            anniversary.category.bottomColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var countdown: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if anniversary.isToday {
                Text("今天")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(anniversary.category.topColor)
            } else if anniversary.daysUntil == 1 {
                Text("明天")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            } else {
                Text("\(anniversary.daysUntil)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                Text("天后")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 44, alignment: .trailing)
    }

    private var monthText: String {
        let c = Anniversary.gregorianCalendar
        return "\(c.component(.month, from: anniversary.nextDate))月"
    }

    private var dayText: String {
        "\(Anniversary.gregorianCalendar.component(.day, from: anniversary.nextDate))"
    }
}

// MARK: - 纪念日行

struct AnniversaryRow: View {
    let anniversary: Anniversary

    var body: some View {
        rowContent
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 0) {
                Text(monthText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(dayText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
            .frame(width: 48, height: 48)
            .background(
                Circle().fill(anniversary.category.topColor.opacity(0.18))
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    if anniversary.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                            .rotationEffect(.degrees(45))
                    }
                    Text(anniversary.title)
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(anniversary.countdownText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            anniversary.isToday
                            ? anniversary.category.topColor
                            : .secondary
                        )

                    if let lunar = anniversary.lunarDateText {
                        Text("· 农历\(lunar)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    if anniversary.isYearly && anniversary.yearsCount > 0 {
                        Text("· \(anniversary.yearsCount) 周年")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if anniversary.reminder != .off {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange.opacity(0.75))
                }
                if !anniversary.notes.isEmpty {
                    Image(systemName: "note.text")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var monthText: String {
        let c = Anniversary.gregorianCalendar
        return "\(c.component(.month, from: anniversary.nextDate))月"
    }

    private var dayText: String {
        "\(Anniversary.gregorianCalendar.component(.day, from: anniversary.nextDate))"
    }
}

// MARK: - 过去行（灰调）

struct PastRow: View {
    let anniversary: Anniversary

    var body: some View {
        rowContent
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 0) {
                Text(monthText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(dayText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(width: 48, height: 48)
            .background(
                Circle().fill(Color.secondary.opacity(0.12))
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(anniversary.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(pastText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)

                    if anniversary.isYearly && anniversary.yearsCount > 0 {
                        Text("· \(anniversary.yearsCount) 周年")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 12)
        .opacity(0.75)
    }

    private var pastText: String {
        guard let d = anniversary.daysSinceLast else { return "" }
        return d == 1 ? "昨天" : "\(d) 天前"
    }

    private var monthText: String {
        guard let last = anniversary.lastDate else { return "" }
        return "\(Anniversary.gregorianCalendar.component(.month, from: last))月"
    }

    private var dayText: String {
        guard let last = anniversary.lastDate else { return "" }
        return "\(Anniversary.gregorianCalendar.component(.day, from: last))"
    }
}
