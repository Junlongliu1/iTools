// DesignSystem.swift
import SwiftUI

enum DSLayout {
    static let cardSpacing: CGFloat = 14
    static let horizontalPadding: CGFloat = 16
    static let cardRadius: CGFloat = 22
    static let rowHorizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 12
}

extension View {
    /// 统一的玻璃卡片外观
    /// 参数类型为 Glass（不是 GlassEffectStyle）
    func cardGlass(_ glass: Glass = .regular) -> some View {
        self.glassEffect(glass, in: .rect(cornerRadius: DSLayout.cardRadius))
    }
}
struct SettingsCardHeader: View {
    let icon: String
    let iconColor: Color
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(iconColor)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, DSLayout.rowHorizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

struct SettingsRow: View {
    let title: String
    let subtitle: String
    let badge: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .medium)).foregroundColor(.primary)
                Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let badge {
                Text(badge)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, DSLayout.rowHorizontalPadding)
        .padding(.vertical, DSLayout.rowVerticalPadding)
        .contentShape(Rectangle())
    }
}

struct SettingsRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.05))
            .frame(height: 0.5)
            .padding(.horizontal, DSLayout.rowHorizontalPadding)
    }
}

struct GlassRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.06 : 0)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
