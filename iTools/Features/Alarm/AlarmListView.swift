// AlarmListView.swift
import SwiftUI

struct AlarmListView: View {
    @StateObject private var store = AlarmStore.shared
    @State private var editingAlarm: AlarmItem?
    @State private var showAdd = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.alarms) { alarm in
                    AlarmRow(alarm: alarm) {
                        store.toggle(alarm)
                    } onEdit: {
                        editingAlarm = alarm
                    }
                }
                .onDelete(perform: store.delete)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("闹钟")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }
            }
            .overlay {
                if store.alarms.isEmpty {
                    ContentUnavailableView("暂无闹钟", systemImage: "alarm", description: Text("点击右上角添加新闹钟"))
                }
            }
            .sheet(isPresented: $showAdd) {
                AlarmEditorView()
            }
            .sheet(item: $editingAlarm) { alarm in
                AlarmEditorView(existing: alarm)
            }
        }
    }
}

private struct AlarmRow: View {
    let alarm: AlarmItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.timeString)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                
                HStack(spacing: 6) {
                    if !alarm.title.isEmpty {
                        Text(alarm.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    if alarm.isHolidayAlarm {
                        Label("节假日", systemImage: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }
}

struct AlarmEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = AlarmStore.shared
    
    @State private var title: String = ""
    @State private var time: Date = Date()
    @State private var isHolidayAlarm: Bool = false
    @State private var isEnabled: Bool = true
    
    let existing: AlarmItem?
    
    init(existing: AlarmItem? = nil) {
        self.existing = existing
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("时间") {
                    DatePicker("提醒时间", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                }
                
                Section("标签") {
                    TextField("闹钟名称（可选）", text: $title)
                }
                
                Section("类型") {
                    Toggle(isOn: $isHolidayAlarm) {
                        Label("节假日闹钟", systemImage: "flag.fill")
                        Text("仅在法定节假日触发")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tint(.orange)
                }
                
                Section {
                    Toggle("启用", isOn: $isEnabled)
                }
            }
            .navigationTitle(existing == nil ? "新建闹钟" : "编辑闹钟")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .bold()
                }
            }
            .onAppear {
                if let e = existing {
                    title = e.title
                    time = e.time
                    isHolidayAlarm = e.isHolidayAlarm
                    isEnabled = e.isEnabled
                }
            }
        }
    }
    
    private func save() {
        let alarm = AlarmItem(
            id: existing?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            time: time,
            isEnabled: isEnabled,
            isHolidayAlarm: isHolidayAlarm
        )
        store.addOrUpdate(alarm)
        dismiss()
    }
}
