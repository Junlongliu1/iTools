// MusicSearchView.swift
import SwiftUI

// MARK: - 搜索状态模型

@MainActor
@Observable
final class MusicSearchModel {
    private let pageSize = 5

    var searchText: String = ""
    var selectedQuality: AudioQuality = .high

    var selectedSource: MusicSource = .netease {
        didSet {
            guard oldValue != selectedSource else { return }
            resetForSourceChange()
        }
    }

    var tracks: [MusicTrack] = []
    var currentPage: Int = 1
    var isSearching = false
    var isLoadingMore = false
    var hasMore = true
    var errorMessage: String?
    var didSearch = false

    func search() async {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        tracks = []
        currentPage = 1
        hasMore = true
        didSearch = true

        do {
            let results = try await MusicAPIService.shared.search(
                keyword: keyword,
                source: selectedSource,
                page: 1,
                count: pageSize
            )
            self.tracks = results
            self.hasMore = results.count >= pageSize
            AppLogInfo("[MusicSearch] 「\(keyword)」@\(selectedSource.rawValue) 第 1 页 → \(results.count) 条")
        } catch {
            self.errorMessage = error.localizedDescription
            AppLogError("[MusicSearch] 失败: \(error.localizedDescription)")
        }

        isSearching = false
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore else { return }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }

        isLoadingMore = true
        let nextPage = currentPage + 1

        do {
            let results = try await MusicAPIService.shared.search(
                keyword: keyword,
                source: selectedSource,
                page: nextPage,
                count: pageSize
            )

            let existing = Set(tracks.map(\.displayKey))
            let newItems = results.filter { !existing.contains($0.displayKey) }

            self.tracks.append(contentsOf: newItems)
            self.currentPage = nextPage
            self.hasMore = results.count >= pageSize

            AppLogInfo("[MusicSearch] 第 \(nextPage) 页 → \(results.count) 条（去重后新增 \(newItems.count)）")
        } catch {
            ToastCenter.shared.show(
                "加载失败：\(error.localizedDescription)",
                icon: "xmark.circle.fill",
                tint: .red
            )
            AppLogError("[MusicSearch] 翻页失败: \(error.localizedDescription)")
        }

        isLoadingMore = false
    }

    func resetForSourceChange() {
        tracks = []
        currentPage = 1
        hasMore = true
        didSearch = false
        errorMessage = nil
    }
}

// MARK: - 主视图

struct MusicSearchView: View {
    @State private var model = MusicSearchModel()
    @State private var showSearchSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DSLayout.cardSpacing) {
                    entryCard
                    attributionFooter
                }
                .padding(.horizontal, DSLayout.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("音乐")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showSearchSheet = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .accessibilityLabel("搜索")

                    NavigationLink {
                        DownloadedMusicView()
                    } label: {
                        Image(systemName: "internaldrive")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .accessibilityLabel("已下载")
                }
            }
            .sheet(isPresented: $showSearchSheet) {
                SearchSheet(model: model)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - 首页入口

    private var entryCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("搜索你喜欢的音乐")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)

            Text("点击右上角 🔍 开始")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button {
                showSearchSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                    Text("开始搜索")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.accentColor))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .cardGlass()
    }

    // MARK: - 页脚署名

    private var attributionFooter: some View {
        VStack(spacing: 4) {
            Text("音乐数据由 GD音乐台 (music.gdstudio.xyz) 提供")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text("资源来自网络，仅供学习参考，请勿传播或商用")
                .font(.system(size: 10))
                .foregroundStyle(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
        .padding(.horizontal, 12)
    }
}

// MARK: - 搜索面板

private struct SearchSheet: View {
    @Bindable var model: MusicSearchModel
    @Environment(\.dismiss) private var dismiss
    @Bindable private var historyStore = SearchHistoryStore.shared
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                ScrollView {
                    GlassEffectContainer(spacing: DSLayout.cardSpacing) {
                        LazyVStack(spacing: DSLayout.cardSpacing) {
                            optionsCard
                            resultArea
                            historySection
                        }
                    }
                    .padding(.horizontal, DSLayout.horizontalPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("搜索音乐")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                isFocused = true
            }
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("搜索歌曲、歌手或专辑", text: $model.searchText)
                .font(.system(size: 15))
                .focused($isFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { submit() }

            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, DSLayout.horizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    // MARK: - 音乐源 + 音质

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "antenna.radiowaves.left.and.right",
                iconColor: .purple,
                title: "音乐源"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MusicSource.ordered) { source in
                        sourceChip(source)
                    }
                }
                .padding(.horizontal, DSLayout.rowHorizontalPadding)
                .padding(.bottom, 4)
            }

            SettingsRowDivider()
                .padding(.top, 8)

            SettingsCardHeader(
                icon: "waveform",
                iconColor: .blue,
                title: "音质"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AudioQuality.allCases) { q in
                        qualityChip(q)
                    }
                }
                .padding(.horizontal, DSLayout.rowHorizontalPadding)
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass()
    }

    private func sourceChip(_ source: MusicSource) -> some View {
        let selected = source == model.selectedSource
        return Button {
            guard source != model.selectedSource else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                model.selectedSource = source   // didSet 自动 resetForSourceChange()
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 4) {
                if source.isStable {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(source.displayName)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(
                    selected
                    ? Color.accentColor.opacity(0.15)
                    : Color.secondary.opacity(0.08)
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func qualityChip(_ q: AudioQuality) -> some View {
        let selected = q == model.selectedQuality
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                model.selectedQuality = q
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Text(q.shortName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(
                        selected
                        ? Color.accentColor.opacity(0.15)
                        : Color.secondary.opacity(0.08)
                    )
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 结果区

    @ViewBuilder
    private var resultArea: some View {
        if model.isSearching {
            loadingCard
        } else if let errorMessage = model.errorMessage {
            errorCard(errorMessage)
        } else if model.didSearch && model.tracks.isEmpty {
            emptyResultCard
        } else if !model.tracks.isEmpty {
            VStack(spacing: DSLayout.cardSpacing) {
                resultCard
                pagingCard
            }
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("正在搜索…")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .cardGlass()
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("重试") {
                Task { await model.search() }
            }
            .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .cardGlass()
    }

    private var emptyResultCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(.secondary.opacity(0.55))
            Text("未找到相关歌曲")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text("尝试更换关键字或音乐源")
                .font(.system(size: 12))
                .foregroundStyle(.secondary.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .cardGlass()
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "list.bullet",
                iconColor: .blue,
                title: "结果（\(model.tracks.count)）· \(model.selectedSource.displayName) · \(model.selectedQuality.shortName)"
            )

            ForEach(model.tracks) { track in
                MusicTrackRow(
                    track: track,
                    quality: model.selectedQuality
                )
                if track.id != model.tracks.last?.id {
                    SettingsRowDivider()
                }
            }
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass()
    }

    @ViewBuilder
    private var pagingCard: some View {
        if model.isLoadingMore {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("正在加载第 \(model.currentPage + 1) 页…")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .cardGlass()

        } else if model.hasMore {
            Button {
                Task { await model.loadMore() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text("加载下一页（第 \(model.currentPage + 1) 页）")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.glass)

        } else {
            Text("已经到底了 · 共 \(model.tracks.count) 首")
                .font(.system(size: 12))
                .foregroundStyle(.secondary.opacity(0.65))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
    }

    // MARK: - 搜索历史

    @ViewBuilder
    private var historySection: some View {
        if historyStore.items.isEmpty {
            emptyHistoryCard
        } else {
            historyCard
        }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("搜索历史")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Button("全部清除") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        historyStore.clear()
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.red)
            }
            .padding(.horizontal, DSLayout.rowHorizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ForEach(historyStore.items, id: \.self) { item in
                historyRow(item)
                if item != historyStore.items.last {
                    SettingsRowDivider()
                }
            }
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass()
    }

    private func historyRow(_ keyword: String) -> some View {
        HStack(spacing: 12) {
            Button {
                selectHistory(keyword)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    Text(keyword)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(GlassRowButtonStyle())

            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    historyStore.remove(keyword)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, DSLayout.rowHorizontalPadding - 8)
        }
        .padding(.leading, DSLayout.rowHorizontalPadding)
        .padding(.vertical, 4)
    }

    private var emptyHistoryCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 26))
                .foregroundStyle(.secondary.opacity(0.45))

            Text("暂无搜索历史")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .cardGlass()
    }

    // MARK: - 提交

    private func submit() {
        let keyword = model.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }

        historyStore.add(keyword)
        isFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { await model.search() }
    }

    private func selectHistory(_ keyword: String) {
        model.searchText = keyword
        historyStore.add(keyword)
        isFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { await model.search() }
    }
}

// MARK: - 曲目行

private struct MusicTrackRow: View {
    let track: MusicTrack
    let quality: AudioQuality

    @Bindable private var downloadManager = MusicDownloadManager.shared

    private var state: DownloadState {
        downloadManager.state(for: track)
    }

    var body: some View {
        HStack(spacing: 12) {
            albumArt
            trackInfo
            Spacer(minLength: 8)
            actionButton
        }
        .padding(.horizontal, DSLayout.rowHorizontalPadding)
        .padding(.vertical, 10)
    }

    private var albumArt: some View {
        CoverImage(
            picId: track.picId,
            source: track.source,
            size: 300
        ) {
            placeholder
        }
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.25),
                         Color.purple.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(track.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(track.artist)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(track.source.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(Color.accentColor.opacity(0.12))
                    )

                if !track.album.isEmpty {
                    Text(track.album)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.75))
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .idle:
            Button {
                downloadManager.download(track: track, quality: quality)
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)

        case .fetchingURL:
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                ProgressView().controlSize(.mini)
            }
            .frame(width: 32, height: 32)

        case .downloading(let progress):
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: max(0.02, progress))
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(width: 32, height: 32)
            .contentShape(Circle())
            .onTapGesture { downloadManager.cancel(track: track) }

        case .completed:
            Button {
                downloadManager.delete(track: track)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)

        case .failed:
            Button {
                downloadManager.resetFailure(track: track)
                downloadManager.download(track: track, quality: quality)
            } label: {
                Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    MusicSearchView()
}
