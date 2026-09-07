// AlarmModels.swift
import Foundation
import Combine
import SwiftUI

struct AlarmItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var time: Date // 只关心时分秒
    var isEnabled: Bool
    var isHolidayAlarm: Bool // 是否为节假日闹钟
    var weekdays: Set<Int>   // 1=周一...7=周日，空表示每天
    
    init(id: UUID = UUID(), title: String = "", time: Date = Date(), isEnabled: Bool = true, isHolidayAlarm: Bool = false, weekdays: Set<Int> = []) {
        self.id = id
        self.title = title
        self.time = time
        self.isEnabled = isEnabled
        self.isHolidayAlarm = isHolidayAlarm
        self.weekdays = weekdays
    }
    
    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: time)
    }
}

class AlarmStore: ObservableObject {
    static let shared = AlarmStore()
    @Published var alarms: [AlarmItem] = [] {
        didSet { save() }
    }
    
    private let key = "saved_alarms_v1"
    
    private init() { load() }
    
    func save() {
        if let data = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([AlarmItem].self, from: data) {
            alarms = decoded
        }
    }
    
    func addOrUpdate(_ alarm: AlarmItem) {
        if let idx = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[idx] = alarm
        } else {
            alarms.append(alarm)
        }
    }
    
    func delete(at offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
    }
    
    func toggle(_ alarm: AlarmItem) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[idx].isEnabled.toggle()
    }
}
