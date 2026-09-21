//
//  CloudRestoreConfirmSheet.swift
//  云端恢复确认（纪念日）
//

import SwiftUI

struct CloudRestoreConfirmSheet: View {

    let file: NutstoreWebDAVClient.RemoteFile
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.14))
                        .frame(width: 76, height: 76)

                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                VStack(spacing: 8) {
                    Text("确认恢复？")
                        .font(.system(size: 18, weight: .semibold))

                    Text("将从云端下载并合并到本机。\n已有的纪念日不会被覆盖，仅补充本地缺少的部分。")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                fileInfoCard

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        onConfirm()
                        dismiss()
                    } label: {
                        Text("开始恢复")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.orange)

                    Button {
                        dismiss()
                    } label: {
                        Text("取消")
                            .font(.system(size: 15))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var fileInfoCard: some View {
        VStack(spacing: 0) {
            infoRow(label: "文件名", value: file.displayName, mono: true)
            Divider().padding(.leading, 16)
            infoRow(label: "大小", value: file.displaySize)
            Divider().padding(.leading, 16)
            if let date = file.modifiedDate {
                infoRow(
                    label: "备份时间",
                    value: date.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private func infoRow(label: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium,
                              design: mono ? .monospaced : .default))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
