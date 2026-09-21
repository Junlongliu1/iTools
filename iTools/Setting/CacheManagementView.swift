// CacheManagementView.swift
import SwiftUI

// MARK: - 缓存分类

private enum CacheCategory: String, CaseIterable, Identifiable {
    case image, metadata, url, log, temp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .image:    return "图片缓存"
        case .metadata: return "元数据缓存"
        case .url:      return "网络缓存"
        case .log:      return "日志归档"
        case .temp:     return "临时文件"
        }
    }

    /// 图例用的短名
    var shortTitle: String {
        switch self {
        case .image:    return "图片"
        case .metadata: return "元数据"
        case .url:      return "网络"
        case .log:      return "日志"
        case .temp:     return "临时"
        }
    }

    var subtitle: String {
        switch self {
        case .image:    return "专辑封面内存与地址缓存"
        case .metadata: return "音频文件内嵌标签与封面"
        case .url:      return "URLSession 响应缓存"
        case .log:      return "历史归档日志"
        case .temp:     return "下载过程残留文件"
        }
    }

    var icon: String {
        switch self {
        case .image:    return "photo.stack.fill"
        case .metadata: return "tag.fill"
        case .url:      return "network"
        case .log:      return "doc.text.fill"
        case .temp:     return "folder.badge.minus"
        }
    }

    var color: Color {
        switch self {
        case .image:    return .pink
        case .metadata: return .purple
        case .url:      return .blue
        case .log:      return .brown
        case .temp:     return .orange
        }
    }
}

// MARK: - 视图

struct CacheManagementView: View {
    private let manager = CacheManager.shared

    @State private var selection: Set<CacheCategory> = []
    @State private var showConfirm = false

    // MARK: Body

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: DSLayout.cardSpacing) {
                LazyVStack(spacing: DSLayout.cardSpacing) {
                    overviewCard
                    detailCard
                    musicCard
                    tipCard
                }
            }
            .padding(.horizontal, DSLayout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("缓存管理")
        .task { await manager.refresh() }
        .refreshable { await manager.refresh() }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .alert(confirmTitle, isPresented: $showConfirm) {
            Button("取消", role: .cancel) {}
            Button("清理", role: .destructive) {
                Task { await cleanSelected() }
            }
        } message: {
            Text(confirmMessage)
        }
    }

    // MARK: - 总览

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "internaldrive.fill",
                iconColor: .indigo,
                title: "缓存总占用"
            )

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(LocalFiles.formattedSize(Int64(manager.totalBytes)))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                if manager.isRefreshing {
                    ProgressView().controlSize(.mini)
                }
            }
            .padding(.horizontal, DSLayout.rowHorizontalPadding)
            .padding(.bottom, 12)

            stackedBar
                .padding(.horizontal, DSLayout.rowHorizontalPadding)
                .padding(.bottom, 10)

            legend
                .padding(.horizontal, DSLayout.rowHorizontalPadding)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass()
    }

    // MARK: - 堆叠条形图

    private var stackedBar: some View {
        GeometryReader { geo in
            let total = CGFloat(max(manager.totalBytes, 1))
            let w = geo.size.width

            HStack(spacing: 0) {
                if manager.imageMemoryBytes > 0 {
                    CacheCategory.image.color
                        .frame(width: w * CGFloat(manager.imageMemoryBytes) / total)
                }
                if manager.metadataBytes > 0 {
                    CacheCategory.metadata.color
                        .frame(width: w * CGFloat(manager.metadataBytes) / total)
                }
                if manager.urlCacheBytes > 0 {
                    CacheCategory.url.color
                        .frame(width: w * CGFloat(manager.urlCacheBytes) / total)
                }
                if manager.logBytes > 0 {
                    CacheCategory.log.color
                        .frame(width: w * CGFloat(manager.logBytes) / total)
                }
                if manager.tempFileBytes > 0 {
                    CacheCategory.temp.color
                        .frame(width: w * CGFloat(manager.tempFileBytes) / total)
                }
                if manager.totalBytes == 0 {
                    Color.secondary.opacity(0.15)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 8)
        .animation(.easeOut(duration: 0.3), value: manager.totalBytes)
    }

    // MARK: - 图例

    private var legend: some View {
        HStack(spacing: 10) {
            ForEach(CacheCategory.allCases) { category in
                HStack(spacing: 4) {
                    Circle()
                        .fill(category.color)
                        .frame(width: 6, height: 6)
                    Text(category.shortTitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 明细 + 选择

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "list.bullet.rectangle",
                iconColor: .blue,
                title: "选择要清理的分类"
            )

            ForEach(Array(CacheCategory.allCases.enumerated()), id: \.element.id) { index, category in
                categoryRow(category)
                if index < CacheCategory.allCases.count - 1 {
                    SettingsRowDivider()
                }
            }
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass()
    }

    private func categoryRow(_ category: CacheCategory) -> some View {
        let bytes = size(for: category)
        let ratio = manager.totalBytes > 0
            ? CGFloat(bytes) / CGFloat(manager.totalBytes)
            : 0
        let isSelected = selection.contains(category)
        let isAvailable = bytes > 0

        return Button {
            guard isAvailable else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                if isSelected {
                    selection.remove(category)
                } else {
                    selection.insert(category)
                }
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        isSelected
                        ? Color.accentColor
                        : Color.secondary.opacity(0.4)
                    )
                    .contentTransition(.symbolEffect(.replace))

                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(category.color)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(category.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)

                        Text(categorySubtitle(category))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .lineLimit(1)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.12))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            category.color.opacity(0.85),
                                            category.color.opacity(0.5)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(geo.size.width * ratio, ratio > 0 ? 4 : 0))
                        }
                    }
                    .frame(height: 5)
                    .animation(.easeOut(duration: 0.3), value: ratio)
                }

                Spacer(minLength: 8)

                Text(LocalFiles.formattedSize(Int64(bytes)))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isAvailable ? .secondary : .tertiary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, DSLayout.rowHorizontalPadding)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassRowButtonStyle())
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.45)
    }

    private func categorySubtitle(_ category: CacheCategory) -> String {
        if category == .image, manager.coverURLCacheCount > 0 {
            return "· \(manager.coverURLCacheCount) 条封面地址"
        }
        return ""
    }

    // MARK: - 已下载音乐（只读）

    private var musicCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "music.note.list",
                iconColor: .green,
                title: "已下载音乐"
            )

            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.green)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalFiles.formattedSize(Int64(manager.musicBytes)))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Text("\(manager.musicFileCount) 个文件 · 用户数据，不参与缓存清理")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, DSLayout.rowHorizontalPadding)
            .padding(.vertical, 12)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass()
    }

    // MARK: - 提示

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "lightbulb.fill",
                iconColor: .yellow,
                title: "说明"
            )

            Text("清理缓存不会影响已下载的音乐文件、搜索结果或个人设置。下次使用时相关资源会自动重新下载。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DSLayout.rowHorizontalPadding)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass()
    }

    // MARK: - 底部操作栏

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                showConfirm = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                    Text(cleanButtonTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .contentTransition(.numericText())
                }
                .foregroundStyle(canClean ? Color.red : Color.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassEffect(
                .regular
                    .tint(canClean ? Color.red.opacity(0.18) : Color.clear)
                    .interactive(),
                in: .capsule
            )
            .disabled(!canClean)
        }
        .padding(.horizontal, DSLayout.horizontalPadding)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    // MARK: - 计算属性

    private var effectiveSelection: Set<CacheCategory> {
        selection.filter { size(for: $0) > 0 }
    }

    private var canClean: Bool {
        !effectiveSelection.isEmpty && !manager.isRefreshing
    }

    private var cleanButtonTitle: String {
        let count = effectiveSelection.count
        if count == 0 { return "请选择要清理的分类" }
        if count == CacheCategory.allCases.filter({ size(for: $0) > 0 }).count {
            return "清理全部选中缓存"
        }
        return "清理选中的 \(count) 项"
    }

    private var confirmTitle: String {
        "清理选中的 \(effectiveSelection.count) 项缓存？"
    }

    private var confirmMessage: String {
        let list = effectiveSelection
            .map(\.title)
            .sorted()
            .joined(separator: "、")
        return "将清理：\(list)。此操作不会影响已下载的音乐。"
    }

    // MARK: - 辅助

    private func size(for category: CacheCategory) -> Int {
        switch category {
        case .image:    return manager.imageMemoryBytes
        case .metadata: return manager.metadataBytes
        case .url:      return manager.urlCacheBytes
        case .log:      return manager.logBytes
        case .temp:     return manager.tempFileBytes
        }
    }

    // MARK: - 清理

    private func cleanSelected() async {
        let targets = effectiveSelection
        guard !targets.isEmpty else { return }

        if targets.contains(.image) {
            await manager.clearImageCaches()
        }
        if targets.contains(.metadata) {
            manager.clearMetadataCache()
        }
        if targets.contains(.url) {
            manager.clearURLCache()
        }
        if targets.contains(.log) {
            await manager.clearLogArchives()
        }
        if targets.contains(.temp) {
            manager.clearTempFiles()
        }

        await manager.refresh()

        withAnimation(.easeOut(duration: 0.2)) {
            selection.removeAll()
        }

        AppLogInfo("[Cache] 清理完成：\(targets.map(\.title).joined(separator: "、"))")
        ToastCenter.shared.show(
            "已清理 \(targets.count) 项缓存",
            icon: "sparkles",
            tint: .green
        )
    }
}

#Preview {
    NavigationStack {
        CacheManagementView()
    }
}
