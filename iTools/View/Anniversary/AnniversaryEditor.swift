// AnniversaryEditor.swift
import SwiftUI
import SwiftData
import UIKit

/// 统一的新建 / 编辑界面
struct AnniversaryEditor: View {

    enum Mode {
        case create
        case edit(Anniversary)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let mode: Mode

    @State private var title = ""
    @State private var date = Date()
    @State private var isYearly = true
    @State private var isLunar = false
    @State private var lunarIsLeapMonth = false
    @State private var category: AnniversaryCategory = .anniversary
    @State private var notes = ""
    @State private var reminder: ReminderOption = .off
    @State private var isPinned = false
    @State private var errorMessage: String?

    init(mode: Mode = .create) {
        self.mode = mode
        if case .edit(let item) = mode {
            _title = State(initialValue: item.title)
            _date = State(initialValue: item.date)
            _isYearly = State(initialValue: item.isYearly)
            _isLunar = State(initialValue: item.isLunar)
            _lunarIsLeapMonth = State(initialValue: item.lunarIsLeapMonth)
            _category = State(initialValue: item.category)
            _notes = State(initialValue: item.notes)
            _reminder = State(initialValue: item.reminder)
            _isPinned = State(initialValue: item.isPinned)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称", text: $title)
                        .submitLabel(.done)
                }

                Section {
                    Toggle("农历", isOn: $isLunar)
                        .onChange(of: isLunar) { _, on in
                            UISelectionFeedbackGenerator().selectionChanged()
                            if on { refreshLunarLeapFlag() }
                        }

                    DatePicker(
                        "日期",
                        selection: $date,
                        displayedComponents: .date
                    )
                    .environment(
                        \.calendar,
                        isLunar ? Anniversary.chineseCalendar : Anniversary.gregorianCalendar
                    )
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .onChange(of: date) { _, _ in
                        if isLunar { refreshLunarLeapFlag() }
                    }

                    if isLunar {
                        Text("选择的是农历日期，每年按农历对应公历自动顺延；闰月无对应年份将回退到非闰月")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("每年重复", isOn: $isYearly)
                }

                Section {
                    Picker("分类", selection: $category) {
                        ForEach(AnniversaryCategory.allCases) { cat in
                            Label(cat.title, systemImage: cat.symbol)
                                .tag(cat)
                        }
                    }
                }

                Section {
                    Picker("提醒", selection: $reminder) {
                        ForEach(ReminderOption.allCases) { opt in
                            Text(opt.title).tag(opt)
                        }
                    }
                    .onChange(of: reminder) { _, new in
                        if new != .off {
                            Task { _ = await ReminderScheduler.requestAuthorization() }
                        }
                    }

                    Toggle("置顶", isOn: $isPinned)
                }

                Section {
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(.regularMaterial)
            .navigationTitle(isEditing ? "编辑纪念日" : "新建纪念日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "添加") { save() }
                        .disabled(trimmedTitle.isEmpty)
                        .buttonStyle(.glassProminent)
                        .tint(.pink)
                }
            }
            .alert("出错了", isPresented: errorBinding) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                if isLunar { refreshLunarLeapFlag() }
            }
        }
    }

    // MARK: - 逻辑

    private func refreshLunarLeapFlag() {
        let lunar = Anniversary.chineseCalendar
        let comps = lunar.dateComponents([.isLeapMonth], from: date)
        lunarIsLeapMonth = comps.isLeapMonth ?? false
    }

    private func save() {
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let item: Anniversary
        switch mode {
        case .create:
            item = Anniversary(
                title: trimmedTitle,
                date: date,
                isYearly: isYearly,
                isLunar: isLunar,
                lunarIsLeapMonth: isLunar ? lunarIsLeapMonth : false,
                notes: cleanNotes,
                category: category,
                isPinned: isPinned,
                reminderAdvanceDays: reminder.rawValue
            )
            context.insert(item)

        case .edit(let existing):
            existing.title = trimmedTitle
            existing.date = date
            existing.isYearly = isYearly
            existing.isLunar = isLunar
            existing.lunarIsLeapMonth = isLunar ? lunarIsLeapMonth : false
            existing.notes = cleanNotes
            existing.category = category
            existing.isPinned = isPinned
            existing.reminderAdvanceDays = reminder.rawValue
            existing.invalidateNextDateCache()
            item = existing
        }

        do {
            try context.save()
        } catch {
            AppLogError("保存纪念日失败 [\(trimmedTitle)]: \(error.localizedDescription)")
            errorMessage = "保存失败：\(error.localizedDescription)"
            return
        }

        Task { await ReminderScheduler.reschedule(item) }

        dismiss()
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
