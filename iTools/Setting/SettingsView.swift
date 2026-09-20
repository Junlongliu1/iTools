// SettingsView.swift
import SwiftUI

private enum SettingsRoute: Hashable {
    case logs
    case about
}

struct SettingsView: View {
    @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: DSLayout.cardSpacing) {
                    appearanceCard
                    developerCard
                    footerNote
                }
                .padding(.horizontal, DSLayout.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .logs:  LogViewerView()
                case .about: AboutView()
                }
            }
        }
    }

    // MARK: - 外观

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(icon: "paintpalette.fill", iconColor: .pink, title: "外观")

            Picker("主题", selection: $appColorScheme) {
                ForEach(AppColorScheme.allCases) { scheme in
                    Text(scheme.displayName).tag(scheme)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DSLayout.rowHorizontalPadding)
            .padding(.bottom, 12)
            .onChange(of: appColorScheme) { _, _ in
                UISelectionFeedbackGenerator().selectionChanged()
            }

            Text("选择「跟随系统」将自动匹配设备深色模式。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DSLayout.rowHorizontalPadding)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: DSLayout.cardRadius))
    }

    // MARK: - 开发者

    private var developerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(icon: "hammer.fill", iconColor: .orange, title: "开发者")

            Button { path.append(SettingsRoute.logs) } label: {
                SettingsRow(title: "调试日志", subtitle: "查看应用运行日志", badge: nil)
            }
            .buttonStyle(GlassRowButtonStyle())

            SettingsRowDivider()

            Button { path.append(SettingsRoute.about) } label: {
                SettingsRow(title: "关于 iTools", subtitle: "版本、开发者与更多信息", badge: nil)
            }
            .buttonStyle(GlassRowButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: DSLayout.cardRadius))
    }

    // MARK: - 脚注

    private var footerNote: some View {
        Text("iTools 是一个轻量的本地工具集，所有数据均保存在本机，不会上传到任何服务器。")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, 4)
    }
}

#Preview {
    SettingsView()
}
