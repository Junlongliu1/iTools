// AboutView.swift
//
//  AboutView.swift
//  iTools
//
//  关于页 —— iOS 26 液态玻璃风格
//

import SwiftUI

struct AboutView: View {
    // MARK: - 版本信息
    private var appVersion: String {
        guard let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            AppLogWarn("[About] CFBundleShortVersionString 缺失，使用默认值 1.0")
            return "1.0"
        }
        return v
    }

    private var buildNumber: String {
        guard let v = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            AppLogWarn("[About] CFBundleVersion 缺失，使用默认值 1")
            return "1"
        }
        return v
    }

    private var copyright: String {
        let year = Calendar.current.component(.year, from: Date())
        return "© \(year) iTools Team"
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.cardSpacing) {
                heroCard
                introCard
                infoCard
                copyrightNote
            }
            .padding(.horizontal, DSLayout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.49, blue: 0.95),
                            Color(red: 0.35, green: 0.28, blue: 0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 84, height: 84)
                .overlay(
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 38))
                        .foregroundColor(.white)
                )
                .shadow(color: .black.opacity(0.18), radius: 10, y: 5)

            VStack(spacing: 4) {
                Text("iTools")
                    .font(.title2.bold())

                Text("版本 \(appVersion) (\(buildNumber))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .glassEffect(.regular, in: .rect(cornerRadius: DSLayout.cardRadius))
    }

    // MARK: - 简介

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(icon: "text.alignleft", iconColor: .blue, title: "简介")

            Text("iTools 是一款轻量的本地工具集，集合音乐、文件、提醒、闹钟等常用能力。所有数据与配置均保存在本机，不会上传到任何服务器。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DSLayout.rowHorizontalPadding)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: DSLayout.cardRadius))
    }

    // MARK: - 信息

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(icon: "info.circle", iconColor: .blue, title: "信息")

            InfoRow(label: "版本",   value: appVersion)
            divider
            InfoRow(label: "构建号", value: buildNumber)
            divider
            InfoRow(label: "系统",   value: systemVersionString)
            divider
            InfoRow(label: "开发者", value: "iTools Team")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: DSLayout.cardRadius))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.05))
            .frame(height: 0.5)
            .padding(.horizontal, DSLayout.rowHorizontalPadding)
    }

    private var systemVersionString: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "iOS \(v.majorVersion).\(v.minorVersion)"
    }

    // MARK: - 版权

    private var copyrightNote: some View {
        Text(copyright)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }
}

// MARK: - 信息行

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, DSLayout.rowHorizontalPadding)
        .padding(.vertical, DSLayout.rowVerticalPadding)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
