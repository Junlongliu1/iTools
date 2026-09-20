// SearchHistoryStore.swift
import Foundation
import Observation

/// 音乐搜索历史存储（UserDefaults 持久化，最多 20 条）
@MainActor
@Observable
final class SearchHistoryStore {
    static let shared = SearchHistoryStore()

    private let storageKey = "music_search_history_v1"
    private let maxItems = 20

    private(set) var items: [String] = []

    private init() {
        items = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
    }

    /// 新增一条历史（去重并置顶）
    func add(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var updated = items.filter { $0 != trimmed }
        updated.insert(trimmed, at: 0)
        if updated.count > maxItems {
            updated = Array(updated.prefix(maxItems))
        }

        items = updated
        persist()
    }

    func remove(_ keyword: String) {
        items.removeAll { $0 == keyword }
        persist()
    }

    func clear() {
        items = []
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(items, forKey: storageKey)
    }
}
