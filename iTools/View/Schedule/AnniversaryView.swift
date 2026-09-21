// AnniversaryView.swift
import SwiftUI
import SwiftData
import UIKit

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

    @State private var showAdd = false
    @State private var selectedCategory: CategorySelection = .all

    /// 未来 30 天内（含今天）、最多 6 个
    private var upcoming: [Anniversary] {
        Array(
            all
                .filter { $0.daysUntil >= 0 && $0.daysUntil <= 30 }
                .sorted {
                    $0.daysUntil != $1.daysUntil
                    ? $0.daysUntil < $1.daysUntil
                    : $0.createdAt < $1.createdAt
                }
                .prefix(6)
        )
    }

    private var selectedItems: [Anniversary] {
        switch selectedCategory {
        case .all:
            return all.sorted { $0.nextDate < $1.nextDate }
        case .category(let c):
            return all.inCategory(c)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    upcomingSection
                        .padding(.horizontal, 16)

                    filterAndList
                }
                .padding(.top, 4)
                .padding(.bottom, 120)
            }
            .background(Color(.systemGroupedBackground))
            .scrollEdgeEffectStyle(.soft, for: .all)
            .navigationTitle("纪念日")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAdd) {
                AddAnniversarySheet()
            }
            .overlay(alignment: .bottomTrailing) { addButton }
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

            if upcoming.isEmpty {
                emptyUpcoming
            } else {
                GlassEffectContainer(spacing: 10) {
                    VStack(spacing: 10) {
                        ForEach(upcoming) { item in
                            UpcomingGlassCard(anniversary: item)
                        }
                    }
                }
                .animation(.smooth(duration: 0.3), value: upcoming.map(\.id))
            }
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

    // MARK: 筛选器 + 结果（视觉成组）

    private var filterAndList: some View {
        VStack(alignment: .leading, spacing: 12) {
            categoryPicker
                .padding(.horizontal, 16)

            inlineList
                .padding(.horizontal, 16)
        }
        .animation(.smooth(duration: 0.28), value: selectedCategory)
        .animation(.smooth(duration: 0.28), value: selectedItems.map(\.id))
    }

    private var categoryPicker: some View {
        Picker("分类", selection: $selectedCategory) {
            ForEach(CategorySelection.allCases) { sel in
                Text(sel.title)
                    .tag(sel)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedCategory) { _, _ in
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    // MARK: 内联列表（当前分类下方）

    @ViewBuilder
    private var inlineList: some View {
        if selectedItems.isEmpty {
            emptyInline
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(selectedItems.enumerated()),
                        id: \.element.id) { index, item in
                    AnniversaryRow(anniversary: item)
                        .padding(.horizontal, 14)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button(role: .destructive) {
                                context.delete(item)
                                try? context.save()
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }

                    if index < selectedItems.count - 1 {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
        }
    }

    private var emptyInline: some View {
        VStack(spacing: 8) {
            Image(systemName: selectedCategory.symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary.opacity(0.6))

            Text("暂无\(selectedCategory.title)")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: 浮动 +

    private var addButton: some View {
        Button {
            showAdd = true
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
}

// MARK: - 即将到来：液态玻璃卡片

struct UpcomingGlassCard: View {
    let anniversary: Anniversary

    var body: some View {
        HStack(spacing: 14) {
            dateBadge

            VStack(alignment: .leading, spacing: 4) {
                Text(anniversary.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

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
        if anniversary.isToday {
            return .regular
                .tint(anniversary.category.topColor.opacity(0.28))
                .interactive()
        }
        return .regular.interactive()
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
        "\(Calendar.current.component(.month, from: anniversary.nextDate))月"
    }

    private var dayText: String {
        "\(Calendar.current.component(.day, from: anniversary.nextDate))"
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
                Circle().fill(anniversary.category.topColor.opacity(0.15))
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(anniversary.title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)

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

            if !anniversary.notes.isEmpty {
                Image(systemName: "note.text")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 12)
    }

    private var monthText: String {
        "\(Calendar.current.component(.month, from: anniversary.nextDate))月"
    }

    private var dayText: String {
        "\(Calendar.current.component(.day, from: anniversary.nextDate))"
    }
}
