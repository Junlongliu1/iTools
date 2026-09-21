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

    static var allCases: [CategorySelection] {
        [.all] + AnniversaryCategory.allCases.map(CategorySelection.category)
    }
}

// MARK: - 主视图

struct AnniversaryView: View {
    @Query(sort: \Anniversary.date) private var all: [Anniversary]
    @Environment(\.modelContext) private var context

    @State private var showCreate = false
    @State private var editingItem: Anniversary?
    @State private var selectedCategory: CategorySelection = .all
    @State private var searchText = ""
    @State private var sortOrder: AnniversarySortOrder = .nextDate

    @State private var pendingDelete: Anniversary?
    @State private var deleteTask: Task<Void, Never>?

    @State private var errorMessage: String?

    @Namespace private var glass

    // MARK: 数据源

    private var displayAll: [Anniversary] {
        guard let p = pendingDelete else { return all }
        return all.filter { $0.persistentModelID != p.persistentModelID }
    }

    /// ✅ 预计算 daysUntil，避免 body 求值时反复调用
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

    /// ✅ 预计算 daysSinceLast
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

        let searched: [Anniversary]
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    upcomingSection
                        .padding(.horizontal, 16)

                    if !recentPast.isEmpty {
                        recentPastSection
                            .padding(.horizontal, 16)
                    }

                    filterAndList
                }
                .padding(.top, 4)
                .padding(.bottom, 120)
            }
            .background(Color(.systemGroupedBackground))
            // ✅ 使用自动边缘效果，深色模式下更自然
            .scrollEdgeEffectStyle(.automatic, for: .all)
            .navigationTitle("纪念日")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索名称或备注")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { sortMenu }
            }
            .sheet(isPresented: $showCreate) {
                AnniversaryEditor(mode: .create)
            }
            .sheet(item: $editingItem) { item in
                AnniversaryEditor(mode: .edit(item))
            }
            .overlay(alignment: .bottomTrailing) { addButton }
            .overlay(alignment: .bottom) { undoToast }
            .alert("出错了", isPresented: errorBinding) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: 即将到来

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("即将到来")
                    .font(.system(size: 20, weight: .bold))

                Spacer()

                if !upcoming.isEmpty {
                    Text("30 天内 \(upcoming.count) 个")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 4)

            // ✅ 容器 spacing 语义 = 玻璃融合阈值；卡片之间希望独立 → 设 0
            GlassEffectContainer(spacing: 0) {
                if upcoming.isEmpty {
                    emptyUpcoming
                        .glassEffectID("upcoming.empty", in: glass)
                } else {
                    VStack(spacing: 10) {
                        ForEach(upcoming) { item in
                            UpcomingGlassCard(anniversary: item)
                                .glassEffectID(item.id, in: glass)
                                .contentShape(Rectangle())
                                .onTapGesture { editingItem = item }
                        }
                    }
                }
            }
            .animation(.smooth(duration: 0.35), value: upcoming.map(\.id))
        }
    }

    private var emptyUpcoming: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary.opacity(0.7))

            Text("未来 30 天没有纪念日")
                .font(.system(size: 15, weight: .medium))

            Text("点击右下角 + 添加，或切换下方分类查看")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: 最近过去

    private var recentPastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("刚刚过去")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Text("30 天内 \(recentPast.count) 个")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(recentPast.enumerated()), id: \.element.id) { index, item in
                    PastRow(anniversary: item)
                        .padding(.horizontal, 14)
                        .contentShape(Rectangle())
                        .onTapGesture { editingItem = item }
                        .contextMenu {
                            Button(role: .destructive) { requestDelete(item) } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }

                    if index < recentPast.count - 1 {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            // ✅ 整块玻璃加入交互反馈
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
            .animation(.smooth(duration: 0.3), value: recentPast.map(\.id))
        }
    }

    // MARK: 筛选器 + 结果

    private var filterAndList: some View {
        VStack(alignment: .leading, spacing: 12) {
            categoryPicker
                .padding(.horizontal, 16)

            Group {
                if selectedItems.isEmpty {
                    emptyInline
                } else {
                    inlineList
                }
            }
            .padding(.horizontal, 16)
        }
        .animation(.smooth(duration: 0.3), value: selectedCategory)
        .animation(.smooth(duration: 0.3), value: selectedItems.map(\.id))
    }

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

    // MARK: ✅ 内联列表：行级玻璃

    private var inlineList: some View {
        GlassEffectContainer(spacing: 0) {
            LazyVStack(spacing: 6) {
                ForEach(selectedItems) { item in
                    AnniversaryRow(anniversary: item)
                        .padding(.horizontal, 14)
                        .contentShape(Rectangle())
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                        .glassEffectID(item.id, in: glass)
                        .onTapGesture { editingItem = item }
                        .contextMenu {
                            Button { editingItem = item } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            Button { togglePin(item) } label: {
                                Label(item.isPinned ? "取消置顶" : "置顶",
                                      systemImage: item.isPinned ? "pin.slash" : "pin")
                            }
                            Divider()
                            Button(role: .destructive) { requestDelete(item) } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private var emptyInline: some View {
        VStack(spacing: 8) {
            Image(systemName: selectedCategory.symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary.opacity(0.6))

            Text(searchText.isEmpty
                 ? "暂无\(selectedCategory.title)"
                 : "没有匹配「\(searchText)」的纪念日")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
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
            Image(systemName: "arrow.up.arrow.down")
        }
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
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    // MARK: 撤销删除 toast

    @ViewBuilder
    private var undoToast: some View {
        if let item = pendingDelete {
            HStack(spacing: 12) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)

                Text("已删除「\(item.title)」")
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button("撤销") { undoDelete() }
                    .font(.subheadline.weight(.semibold))
                    .tint(.pink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
            .padding(.horizontal, 20)
            .padding(.bottom, 92)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(item.persistentModelID)
            // ✅ VoiceOver：合并为一个元素
            .accessibilityElement(children: .combine)
            .accessibilityLabel("已删除 \(item.title)")
            .accessibilityHint("双击撤销按钮恢复")
        }
    }

    // MARK: 操作

    private func togglePin(_ item: Anniversary) {
        item.isPinned.toggle()
        saveContext()
    }

    private func requestDelete(_ item: Anniversary) {
        deleteTask?.cancel()

        if let prev = pendingDelete, prev.persistentModelID != item.persistentModelID {
            // 上一次未落定 → 先落定；失败则回滚
            if !performDelete(prev) {
                withAnimation(.smooth(duration: 0.3)) { pendingDelete = nil }
                return
            }
        }

        withAnimation(.smooth(duration: 0.3)) {
            pendingDelete = item
        }

        // ✅ VoiceOver 播报
        AccessibilityNotification.Announcement("已删除 \(item.title)").post()

        deleteTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard pendingDelete?.persistentModelID == item.persistentModelID else { return }
                let ok = performDelete(item)
                withAnimation(.smooth(duration: 0.3)) {
                    // ✅ 失败时恢复，让用户看到错误
                    pendingDelete = ok ? nil : item
                }
            }
        }
    }

    private func undoDelete() {
        deleteTask?.cancel()
        deleteTask = nil
        withAnimation(.smooth(duration: 0.3)) {
            pendingDelete = nil
        }
    }

    /// ✅ 返回是否成功，供调用方决定是否回滚
    @discardableResult
    private func performDelete(_ item: Anniversary) -> Bool {
        ReminderScheduler.cancel(item)
        context.delete(item)
        do {
            try context.save()
            return true
        } catch {
            errorMessage = "操作失败：\(error.localizedDescription)"
            return false
        }
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            errorMessage = "操作失败：\(error.localizedDescription)"
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

// MARK: - 即将到来：液态玻璃卡片

struct UpcomingGlassCard: View {
    let anniversary: Anniversary

    var body: some View {
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
            g = g.tint(anniversary.category.topColor.opacity(0.28))
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
