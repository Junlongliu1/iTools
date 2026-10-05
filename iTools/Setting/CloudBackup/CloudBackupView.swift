//
//  CloudBackupView.swift
//  纪念日云盘备份（iOS 26 液态玻璃）
//

import SwiftUI

// MARK: - 品牌色

private extension Color {
    static let nutstoreGreen     = Color(red: 0.15, green: 0.65, blue: 0.35)
    static let nutstoreGreenDeep = Color(red: 0.10, green: 0.50, blue: 0.28)
    static let nutstoreRed       = Color(red: 0.94, green: 0.32, blue: 0.38)
}

// MARK: - Toast 类型

enum ToastType {
    case success, error, info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .success: return .green
        case .error:   return .red
        case .info:    return .blue
        }
    }
}

// MARK: - 布局常量

private enum Layout {
    static let horizontalPadding: CGFloat     = 16
    static let cardCorner: CGFloat            = 18
    static let cardSpacing: CGFloat           = 14
    static let cardHeaderHorizontal: CGFloat  = 16
}

struct CloudBackupView: View {

    @StateObject private var auth     = NutstoreAuth.shared
    @StateObject private var manager  = CloudBackupManager.shared
    @StateObject private var settings = CloudBackupSettings.shared

    @State private var showLoginSheet    = false
    @State private var showFolderPicker  = false
    @State private var showLogoutConfirm = false
    @State private var restoreTarget: NutstoreWebDAVClient.RemoteFile?
    @State private var toastMessage: (String, ToastType)?
    @State private var toastTask: Task<Void, Never>?
    @State private var isPolicyExpanded  = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Layout.cardSpacing) {
                if auth.isLoggedIn {
                    accountCard
                    folderCard
                    policyCard
                    remoteFilesCard
                    manualBackupCard
                } else {
                    loginPromptCard
                }
                footerNote
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("云盘备份")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if auth.isLoggedIn {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshRemoteFiles() }
                    } label: {
                        if manager.state == .listing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(manager.state != .idle)
                    .accessibilityLabel("刷新云端文件")
                }
            }
        }
        .task {
            guard auth.isLoggedIn else { return }
            await refreshRemoteFiles()
        }
        .sheet(isPresented: $showLoginSheet) {
            NutstoreLoginSheet()
        }
        .sheet(isPresented: $showFolderPicker) {
            CloudFolderPickerView(initialPath: settings.folderPath) { newPath in
                settings.folderPath = newPath
            }
        }
        .sheet(item: $restoreTarget) { file in
            CloudRestoreConfirmSheet(file: file) {
                Task { await performRestore(file) }
            }
        }
        .alert("退出登录", isPresented: $showLogoutConfirm) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                auth.logout()
                manager.resetClient()
            }
        } message: {
            Text("退出后将停止自动备份，云端已备份的文件不会删除。")
        }
        .overlay(alignment: .top) {
            if let (msg, type) = toastMessage {
                toastBanner(msg, type)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: auth.isLoggedIn)
        .animation(.spring(duration: 0.4), value: manager.remoteFiles.count)
    }

    // MARK: - 未登录卡片

    private var loginPromptCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.nutstoreGreen, .nutstoreGreenDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: "cloud.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text("坚果云备份")
                    .font(.system(size: 17, weight: .semibold))

                Text("登录坚果云后，可将纪念日自动备份到云端，\n换机时也能一键恢复。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                showLoginSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("登录坚果云")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            }
            .buttonStyle(.glassProminent)
            .tint(.nutstoreGreen)

            Text("在坚果云网页版「账户信息 → 安全选项」中\n生成应用密码后填入")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: - 账户卡

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(icon: "person.crop.circle.fill",
                       iconColor: .nutstoreGreen,
                       title: "账户")

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.nutstoreGreen.opacity(0.14))
                        .frame(width: 44, height: 44)

                    Image(systemName: "cloud.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.nutstoreGreen)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(auth.accountEmail ?? "已登录")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("已连接坚果云")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Button {
                    showLogoutConfirm = true
                } label: {
                    Text("退出登录")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.nutstoreRed)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.nutstoreRed.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("退出坚果云登录")
            }
            .padding(.horizontal, Layout.cardHeaderHorizontal)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Layout.cardCorner))
    }

    // MARK: - 文件夹卡

    private var folderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(icon: "folder.fill",
                       iconColor: .blue,
                       title: "备份文件夹")

            Button {
                showFolderPicker = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: "folder")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("我的坚果云 / \(settings.folderPath)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text("点击选择其他文件夹")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, Layout.cardHeaderHorizontal)
                .padding(.bottom, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Layout.cardCorner))
    }

    // MARK: - 自动备份策略卡

    private var policyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(icon: "clock.arrow.circlepath",
                       iconColor: .orange,
                       title: "自动备份")

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isPolicyExpanded.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("备份频率")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)

                        Text(settings.policy.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .contentTransition(.opacity)
                    }

                    Spacer(minLength: 6)

                    HStack(spacing: 4) {
                        Text(settings.policy.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .contentTransition(.opacity)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isPolicyExpanded ? -180 : 0))
                    }
                }
                .padding(.horizontal, Layout.cardHeaderHorizontal)
                .padding(.bottom, isPolicyExpanded ? 4 : 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isPolicyExpanded {
                Divider().padding(.horizontal, Layout.cardHeaderHorizontal)

                VStack(spacing: 0) {
                    ForEach(CloudBackupSettings.BackupPolicy.allCases) { policy in
                        policyOptionRow(policy)

                        if policy != CloudBackupSettings.BackupPolicy.allCases.last {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .padding(.vertical, 4)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal:   .opacity.combined(with: .move(edge: .top))
                    )
                )
            }

            if let last = settings.lastBackupDate {
                Divider().padding(.horizontal, Layout.cardHeaderHorizontal)

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                    Text("上次备份：\(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, Layout.cardHeaderHorizontal)
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Layout.cardCorner))
    }

    private func policyOptionRow(_ policy: CloudBackupSettings.BackupPolicy) -> some View {
        let isSelected = settings.policy == policy

        return Button {
            selectPolicy(policy)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.orange : Color.secondary.opacity(0.35))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(policy.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(policy.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, Layout.cardHeaderHorizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isSelected)
    }

    // MARK: - 云端备份列表

    private var remoteFilesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(icon: "externaldrive.fill.badge.icloud",
                       iconColor: .purple,
                       title: "云端备份")

            if manager.state == .listing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("正在获取文件列表...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, Layout.cardHeaderHorizontal)
                .padding(.bottom, 16)
            } else if manager.remoteFiles.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                    Text("云端暂无备份文件")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, Layout.cardHeaderHorizontal)
                .padding(.bottom, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(manager.remoteFiles) { file in
                        remoteFileRow(file)

                        if file.id != manager.remoteFiles.last?.id {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .padding(.bottom, 6)

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text("云端仅保留最近 3 次备份，旧的会自动清理")
                        .font(.system(size: 11))
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, Layout.cardHeaderHorizontal)
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Layout.cardCorner))
    }

    private func remoteFileRow(_ file: NutstoreWebDAVClient.RemoteFile) -> some View {
        Button {
            restoreTarget = file
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 34, height: 34)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 6) {
                        if let date = file.modifiedDate {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                        }
                        Text("·")
                        Text(file.displaySize)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                Text("恢复")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, Layout.cardHeaderHorizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("恢复备份 \(file.displayName)")
    }

    // MARK: - 手动备份

    private var manualBackupCard: some View {
        Button {
            Task { await performManualBackup() }
        } label: {
            HStack(spacing: 10) {
                if manager.state == .uploading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                    Text("备份中...")
                        .font(.system(size: 15, weight: .semibold))
                } else {
                    Image(systemName: "arrow.up.to.line.compact")
                        .font(.system(size: 15, weight: .semibold))
                    Text("立即备份")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
        }
        .buttonStyle(.glassProminent)
        .tint(.nutstoreGreen)
        .disabled(manager.state != .idle)
    }

    // MARK: - Footer

    private var footerNote: some View {
        Text("备份文件为纪念日的 JSON 快照，包含名称、日期、分类、农历设置与提醒偏好。\n恢复采用合并模式，按 uuid 去重，不会覆盖已有数据。")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }

    // MARK: - 卡片标题

    private func cardHeader(icon: String, iconColor: Color, title: String) -> some View {
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
        .padding(.horizontal, Layout.cardHeaderHorizontal)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Toast

    private func toastBanner(_ message: String, _ type: ToastType) -> some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .font(.system(size: 16))
                .foregroundStyle(type.accentColor)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(
            .regular.tint(type.accentColor.opacity(0.18)),
            in: .rect(cornerRadius: 14)
        )
        .padding(.horizontal, Layout.horizontalPadding)
    }

    private func showToast(_ message: String, _ type: ToastType) {
        toastTask?.cancel()
        withAnimation(.spring(duration: 0.4)) {
            toastMessage = (message, type)
        }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                toastMessage = nil
            }
        }
    }

    // MARK: - Actions

    private func selectPolicy(_ policy: CloudBackupSettings.BackupPolicy) {
        guard settings.policy != policy else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isPolicyExpanded = false
            }
            return
        }

        settings.policy = policy
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showToast("已切换为\(policy.displayName)自动备份", .success)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isPolicyExpanded = false
        }
    }

    private func refreshRemoteFiles() async {
        do {
            try await manager.refreshRemoteFiles()
        } catch {
            AppLogError("[CloudBackupView] 刷新远端失败: \(error.localizedDescription)")
            showToast(error.localizedDescription, .error)
        }
    }

    private func performManualBackup() async {
        do {
            let outcome = try await manager.performManualBackup()
            switch outcome {
            case .uploaded(let fileName):
                showToast("备份成功：\(fileName)", .success)
                await refreshRemoteFiles()
            case .skippedNoChange:
                showToast("数据无变化，已跳过", .info)
            }
        } catch {
            AppLogError("[CloudBackupView] 手动备份失败: \(error.localizedDescription)")
            showToast(error.localizedDescription, .error)
        }
    }

    private func performRestore(_ file: NutstoreWebDAVClient.RemoteFile) async {
        defer { restoreTarget = nil }
        do {
            let result = try await manager.restore(from: file)
            UINotificationFeedbackGenerator().notificationOccurred(
                result.added > 0 ? .success : .warning
            )
            showToast(result.summary, result.added > 0 ? .success : .info)
        } catch {
            AppLogError("[CloudBackupView] 恢复失败: \(error.localizedDescription)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showToast(error.localizedDescription, .error)
        }
    }
}

#Preview {
    NavigationStack {
        CloudBackupView()
    }
}
