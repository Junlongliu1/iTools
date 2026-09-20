// ToastView.swift
// iOS 26 液态玻璃风格 Toast
import SwiftUI

// MARK: - Toast 视图

struct ToastView: View {
    let message: String
    var icon: String? = nil
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - 全局 Toast 中心

@MainActor
@Observable
final class ToastCenter {
    static let shared = ToastCenter()

    private(set) var message: String?
    private(set) var icon: String?
    private(set) var tint: Color = .accentColor

    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    private init() {}

    /// 显示一条 Toast，默认 1.8 秒后自动消失
    func show(
        _ message: String,
        icon: String? = "checkmark.circle.fill",
        tint: Color = .accentColor,
        duration: Duration = .seconds(1.8)
    ) {
        self.message = message
        self.icon = icon
        self.tint = tint

        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    self?.message = nil
                }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        withAnimation(.easeOut(duration: 0.2)) {
            message = nil
        }
    }
}

// MARK: - 便捷修饰符

extension View {
    /// 挂在根视图上，自动渲染 ToastCenter 的消息
    func toastOverlay() -> some View {
        modifier(ToastOverlayModifier())
    }
}

private struct ToastOverlayModifier: ViewModifier {
    @Bindable private var center = ToastCenter.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message = center.message {
                ToastView(message: message, icon: center.icon, tint: center.tint)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .zIndex(999)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: center.message)
    }
}
