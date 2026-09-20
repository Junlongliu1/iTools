// CoverRequestCoordinator.swift
import Foundation

/// 封面请求协调器：
/// - 全局串行限流（1.2s 间隔），避免 5 张封面并发触发 503
/// - 失败负缓存 5 分钟
actor CoverRequestCoordinator {
    static let shared = CoverRequestCoordinator()

    /// ★ 与 API 层 coverRateLimiter 叠加，这里再加一层串行间隔
    private let minInterval: TimeInterval = 1.2
    private let negativeCacheTTL: TimeInterval = 300

    private var nextSlotTime: Date = .distantPast
    private var negativeCache: [String: Date] = [:]
    
    /// 清空 503 负缓存（缓存管理页「清除图片缓存」调用）
    func clearNegativeCache() {
        negativeCache.removeAll()
    }

    func waitForSlot() async {
        let now = Date()
        let scheduled = max(now, nextSlotTime)
        nextSlotTime = scheduled.addingTimeInterval(minInterval)

        let delay = scheduled.timeIntervalSince(now)
        if delay > 0 {
            try? await Task.sleep(for: .seconds(delay))
        }
    }

    func shouldAttempt(key: String) -> Bool {
        guard let failedAt = negativeCache[key] else { return true }
        if Date().timeIntervalSince(failedAt) < negativeCacheTTL {
            return false
        }
        negativeCache.removeValue(forKey: key)
        return true
    }

    func markFailed(key: String) {
        negativeCache[key] = Date()
    }

    func markSuccess(key: String) {
        negativeCache.removeValue(forKey: key)
    }
}
