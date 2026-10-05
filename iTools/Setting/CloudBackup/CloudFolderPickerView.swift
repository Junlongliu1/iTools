//
//  CloudFolderPickerView.swift
//  坚果云文件夹选择器
//

import SwiftUI

struct CloudFolderPickerView: View {

    let initialPath: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var currentPath: [String] = []
    @State private var directories: [NutstoreWebDAVClient.RemoteFile] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var newFolderName = ""
    @State private var showCreateFolder = false

    private var pathString: String { currentPath.joined(separator: "/") }

    private var displayPath: String {
        currentPath.isEmpty ? "我的坚果云"
        : "我的坚果云 / " + currentPath.joined(separator: " / ")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    breadcrumbBar
                    content
                }
            }
            .navigationTitle("选择文件夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("选择") {
                        onSelect(pathString.isEmpty ? "AnniversaryBackup" : pathString)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCreateFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
            .task {
                currentPath = initialPath
                    .split(separator: "/")
                    .map(String.init)
                    .filter { !$0.isEmpty }
                await loadDirectories()
            }
            .alert("新建文件夹", isPresented: $showCreateFolder) {
                TextField("文件夹名称", text: $newFolderName)
                Button("取消", role: .cancel) { newFolderName = "" }
                Button("创建") {
                    Task { await createFolder() }
                }
            } message: {
                Text("将在「\(displayPath)」下创建新文件夹")
            }
        }
    }

    // MARK: - 面包屑

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button {
                    currentPath = []
                    Task { await loadDirectories() }
                } label: {
                    breadcrumbItem(text: "我的坚果云", isCurrent: currentPath.isEmpty)
                }
                .buttonStyle(.plain)

                ForEach(Array(currentPath.enumerated()), id: \.offset) { index, name in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)

                    Button {
                        currentPath = Array(currentPath.prefix(index + 1))
                        Task { await loadDirectories() }
                    } label: {
                        breadcrumbItem(
                            text: name,
                            isCurrent: index == currentPath.count - 1
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private func breadcrumbItem(text: String, isCurrent: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
            .foregroundStyle(isCurrent ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(isCurrent ? Color.accentColor.opacity(0.12) : Color.clear)
            )
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("加载中...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            ContentUnavailableView {
                Label("加载失败", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("重试") {
                    Task { await loadDirectories() }
                }
            }
        } else if directories.isEmpty {
            ContentUnavailableView {
                Label("此文件夹为空", systemImage: "folder")
            } description: {
                Text("点击「选择」使用当前文件夹")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(directories) { dir in
                        Button {
                            currentPath.append(dir.displayName)
                            Task { await loadDirectories() }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Color.blue.opacity(0.12))
                                        .frame(width: 34, height: 34)

                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.blue)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dir.displayName)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    if let date = dir.modifiedDate {
                                        Text(date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 62)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - 加载

    private func loadDirectories() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let root = NutstoreAuth.shared.webdavRoot else {
                throw NutstoreError.invalidResponse
            }
            let client = NutstoreWebDAVClient(auth: NutstoreAuth.shared, baseURL: root)
            let all = try await client.listDirectory(at: pathString)

            directories = all
                .filter { $0.isDirectory }
                .sorted { $0.displayName < $1.displayName }

            AppLogInfo("[FolderPicker] path=\(pathString) dirs=\(directories.count)")
        } catch {
            AppLogError("[FolderPicker] 加载失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    private func createFolder() async {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        newFolderName = ""
        guard !name.isEmpty else { return }

        do {
            guard let root = NutstoreAuth.shared.webdavRoot else { return }
            let client = NutstoreWebDAVClient(auth: NutstoreAuth.shared, baseURL: root)
            let target = pathString.isEmpty ? name : "\(pathString)/\(name)"
            try await client.createDirectory(at: target)
            await loadDirectories()
        } catch {
            AppLogError("[FolderPicker] 创建文件夹失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
