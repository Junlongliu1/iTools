// CoverRequestCoordinator.swift
import Foundation

/// 封面请求协调器：
/// - 全局串行限流（默认 800ms 间隔），避免 5 张封面并发触发 503
/// - 失败负缓存 5 分钟，避免反复重试同一失效 picId
actor CoverRequestCoordinator {
    static let shared = CoverRequestCoordinator()

    /// 两次 pic 请求之间至少间隔（秒）
    private let minInterval: TimeInterval = 0.8

    /// 失败负缓存有效期（秒）
    private let negativeCacheTTL: TimeInterval = 300

    /// ★ 原子预约：每个调用者拿独占时间槽，strictly serial
    private var nextSlotTime: Date = .distantPast
    private var negativeCache: [String: Date] = [:]

    /// 原子地预约一个时间槽，然后 sleep 到该时间点
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
