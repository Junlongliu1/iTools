// AddAnniversarySheet.swift
import SwiftUI
import SwiftData
import UIKit

/// 新建纪念日
struct AddAnniversarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var date = Date()
    @State private var isYearly = true
    @State private var isLunar = false
    @State private var category: AnniversaryCategory = .anniversary
    @State private var notes = ""

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称", text: $title)
                }

                Section {
                    Toggle("农历", isOn: $isLunar)
                        .onChange(of: isLunar) { _, _ in
                            UISelectionFeedbackGenerator().selectionChanged()
                        }

                    DatePicker(
                        "日期",
                        selection: $date,
                        displayedComponents: .date
                    )
                    .environment(
                        \.calendar,
                        isLunar ? Calendar(identifier: .chinese) : .current
                    )
                    .environment(\.locale, Locale(identifier: "zh_CN"))

                    if isLunar {
                        Text("选择的是农历日期，每年按农历对应公历自动顺延")
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
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("新建纪念日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { add() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }

    private func add() {
        let item = Anniversary(
            title: trimmedTitle,
            date: date,
            isYearly: isYearly,
            isLunar: isLunar,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category
        )
        context.insert(item)
        do {
            try context.save()
        } catch {
            print("❌ 保存失败:", error)
        }
        dismiss()
    }
}
