// DownloadedMusicView.swift
import SwiftUI

struct DownloadedMusicView: View {

    @State private var files: [URL] = []
    @State private var totalSize: Int64 = 0
    @State private var selectedFile: URL?
    @State private var showClearConfirm = false
    @State private var pendingDelete: URL?

    var body: some View {
        Group {
            if files.isEmpty {
                emptyState
            } else {
                contentList
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("已下载")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        LocalFiles.openInFilesApp()
                    } label: {
                        Label("在文件 App 中查看", systemImage: "folder")
                    }

                    Button {
                        LocalFiles.share(files)
                    } label: {
                        Label("分享全部", systemImage: "square.and.arrow.up")
                    }
                    .disabled(files.isEmpty)

                    Divider()

                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("全部删除", systemImage: "trash")
                    }
                    .disabled(files.isEmpty)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("更多操作")
            }
        }
        .onAppear(perform: reload)
        .sheet(item: Binding(
            get: { selectedFile.map(FileInfo.init) },
            set: { selectedFile = $0?.url }
        )) { info in
            FileDetailSheet(url: info.url, onDelete: {
                selectedFile = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    deleteFile(info.url)
                }
            })
        }
        .alert(
            "删除文件？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { url in
            Button("删除", role: .destructive) { performDelete(url) }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: { url in
            Text("将删除「\(displayTitle(url))」，此操作无法撤销。")
        }
        .alert("清空全部？", isPresented: $showClearConfirm) {
            Button("清空", role: .destructive) { clearAll() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除 \(files.count) 个文件（\(LocalFiles.formattedSize(totalSize))），此操作无法撤销。")
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("暂无下载")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            Text("在音乐页搜索并下载歌曲后会显示在这里")
                .font(.system(size: 12))
                .foregroundStyle(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 列表

    private var contentList: some View {
        ScrollView {
            GlassEffectContainer(spacing: DSLayout.cardSpacing) {
                LazyVStack(spacing: DSLayout.cardSpacing) {
                    storageCard
                    fileListCard
                }
            }
            .padding(.horizontal, DSLayout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    // MARK: 存储概览

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "internaldrive.fill",
                iconColor: .indigo,
                title: "存储占用"
            )

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(LocalFiles.formattedSize(totalSize))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                Text("·")
                    .foregroundStyle(.secondary.opacity(0.5))

                Text("\(files.count) 个文件")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DSLayout.rowHorizontalPadding)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass()
    }

    // MARK: 文件列表

    private var fileListCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "music.note.list",
                iconColor: .pink,
                title: "本地文件"
            )

            ForEach(files, id: \.self) { url in
                fileRow(url: url)
                if url != files.last {
                    SettingsRowDivider()
                }
            }
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass()
    }

    private func fileRow(url: URL) -> some View {
        let track = TrackMetaCache.shared.track(for: url)

        return HStack(spacing: 12) {
            Button {
                selectedFile = url
            } label: {
                HStack(spacing: 12) {
                    coverThumbnail(for: url, track: track)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track?.name.isEmpty == false
                             ? track!.name
                             : url.deletingPathExtension().lastPathComponent)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(subtitle(url, track: track))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(GlassRowButtonStyle())

            Menu {
                Button {
                    LocalFiles.share([url])
                } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                }

                Button {
                    UIPasteboard.general.url = url
                    ToastCenter.shared.show("路径已复制", icon: "doc.on.doc")
                } label: {
                    Label("复制路径", systemImage: "doc.on.doc")
                }

                Divider()

                Button(role: .destructive) {
                    pendingDelete = url
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .padding(.trailing, DSLayout.rowHorizontalPadding - 8)
        }
        .padding(.leading, DSLayout.rowHorizontalPadding)
        .padding(.vertical, 4)
    }

    // MARK: - 封面缩略图

    @ViewBuilder
    private func coverThumbnail(for url: URL, track: MusicTrack?) -> some View {
        CoverImage(
            picId: track?.picId ?? "",
            source: track?.source ?? .netease,
            localFile: LocalFiles.coverURL(for: url),
            size: 300
        ) {
            fallbackThumbnail
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }

    private var fallbackThumbnail: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.22),
                         Color.purple.opacity(0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.accentColor)
        }
    }

    // MARK: - 辅助

    private func displayTitle(_ url: URL) -> String {
        if let track = TrackMetaCache.shared.track(for: url), !track.name.isEmpty {
            return track.name
        }
        return url.deletingPathExtension().lastPathComponent
    }

    private func subtitle(_ url: URL, track: MusicTrack?) -> String {
        let size = LocalFiles.formattedSize(LocalFiles.fileSize(url))

        if let track, !track.artist.isEmpty {
            return "\(track.artist) · \(size)"
        }
        return "\(size) · \(LocalFiles.formattedDate(url))"
    }

    // MARK: - 操作

    private func reload() {
        files = LocalFiles.listDownloadedMusic()
        totalSize = LocalFiles.totalMusicSize()
        for url in files {
            _ = TrackMetaCache.shared.track(for: url)
        }
        AppLogInfo("[Downloaded] 加载 \(files.count) 个文件，共 \(LocalFiles.formattedSize(totalSize))")
    }

    private func deleteFile(_ url: URL) {
        if LocalFiles.delete(url) {
            ToastCenter.shared.show("已删除", icon: "trash.fill", tint: .red)
            withAnimation(.easeOut(duration: 0.2)) { reload() }
        }
    }

    private func performDelete(_ url: URL) {
        deleteFile(url)
        pendingDelete = nil
    }

    private func clearAll() {
        let n = LocalFiles.deleteAll()
        AppLogInfo("[Downloaded] 清空 \(n) 个文件")
        ToastCenter.shared.show("已清空 \(n) 个文件", icon: "trash.fill", tint: .red)
        withAnimation(.easeOut(duration: 0.2)) { reload() }
    }
}

// MARK: - sheet 辅助类型

private struct FileInfo: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - 文件详情

private struct FileDetailSheet: View {
    let url: URL
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    private var track: MusicTrack? { TrackMetaCache.shared.track(for: url) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    infoCard
                }
                .padding(.horizontal, DSLayout.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("文件信息")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
            .alert("删除文件？", isPresented: $showDeleteConfirm) {
                Button("删除", role: .destructive) {
                    dismiss()
                    onDelete()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作无法撤销。")
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            CoverImage(
                picId: track?.picId ?? "",
                source: track?.source ?? .netease,
                localFile: LocalFiles.coverURL(for: url),
                size: 300
            ) {
                bigFallback
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)

            VStack(spacing: 4) {
                Text(track?.name ?? url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 20)

                if let track, !track.artist.isEmpty {
                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 20)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var bigFallback: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.35, blue: 0.55),
                    Color(red: 0.60, green: 0.30, blue: 0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(icon: "doc.text", iconColor: .blue, title: "详细信息")

            if let track {
                infoRow(label: "歌曲", value: track.name)
                SettingsRowDivider()
                infoRow(label: "歌手", value: track.artist)
                SettingsRowDivider()
                if !track.album.isEmpty {
                    infoRow(label: "专辑", value: track.album)
                    SettingsRowDivider()
                }
                infoRow(label: "音乐源", value: track.source.displayName)
                SettingsRowDivider()
            }

            infoRow(label: "文件名", value: url.lastPathComponent)
            SettingsRowDivider()
            infoRow(label: "大小",   value: LocalFiles.formattedSize(LocalFiles.fileSize(url)))
            SettingsRowDivider()
            infoRow(label: "格式",   value: url.pathExtension.uppercased())
            SettingsRowDivider()
            infoRow(label: "创建时间", value: LocalFiles.formattedDate(url))
            SettingsRowDivider()
            infoRow(label: "位置",   value: "Documents/Music/", monospaced: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass()
    }

    private func infoRow(label: String, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.system(size: 13, design: monospaced ? .monospaced : .default))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DSLayout.rowHorizontalPadding)
        .padding(.vertical, DSLayout.rowVerticalPadding)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                let targets = [url]
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    LocalFiles.share(targets)
                }
            } label: {
                Label("分享", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(GlassButtonStyle())

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("删除", systemImage: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(GlassButtonStyle())
        }
        .padding(.horizontal, DSLayout.horizontalPadding)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}

// MARK: - 玻璃按钮样式

private struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassEffect(
                configuration.isPressed
                ? .regular.tint(Color.primary.opacity(0.15)).interactive()
                : .regular.interactive(),
                in: .capsule
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        DownloadedMusicView()
    }
}
