//  日志查看器

import SwiftUI

struct LogViewerView: View {
    @ObservedObject private var logManager = LogManager.shared      // 共享日志管理器实例
    @State private var autoScroll = true                            // 是否自动滚动到底部
    @State private var showCopySuccess = false                      // 是否显示复制成功提示
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部控制栏
            controlBar
            
            Divider()
            
            // 日志内容区
            logContentArea
            
            Divider()
            
            // 底部操作栏
            bottomActionBar
        }
        .navigationTitle("开发者选项")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            logManager.loadTodayLog()
        }
        .overlay {
            if showCopySuccess {
                ToastView(message: "已复制到剪贴板")
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // 顶部控制栏
    private var controlBar: some View {
        HStack(spacing: 8) {
            // 控制台输出开关
            Toggle(isOn: $logManager.consoleEnabled) {
                HStack(spacing: 3) {
                    Image(systemName: logManager.consoleEnabled ? "terminal.fill" : "terminal")
                        .font(.caption2)
                    Text("控制台")
                        .font(.caption2)
                }
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            // 文件写入开关
            Toggle(isOn: $logManager.fileWriteEnabled) {
                HStack(spacing: 3) {
                    Image(systemName: logManager.fileWriteEnabled ? "doc.text.fill" : "doc.text")
                        .font(.caption2)
                    Text("写文件")
                        .font(.caption2)
                }
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            // 自动滚动开关
            Toggle(isOn: $autoScroll) {
                HStack(spacing: 3) {
                    Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .font(.caption2)
                    Text("滚动")
                        .font(.caption2)
                }
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Spacer()
            
            // 日志统计
            Text("\(max(0, logManager.logContent.components(separatedBy: "\n").count - 1)) 行")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // 日志内容区
    private var logContentArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if logManager.logContent.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(Array(logManager.logContent.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
                            if !line.isEmpty {
                                logLineView(line: line, index: index)
                            }
                        }
                    }
                }
                .padding(8)
                .id("logBottom")
            }
            .onChange(of: logManager.logContent) {
                if autoScroll {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("logBottom", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    //  单行日志视图
    private func logLineView(line: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(index + 1)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)
            
            Text(line)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .background(index % 2 == 0 ? Color.clear : Color(.systemGray6).opacity(0.3))
    }
    
    //  空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("暂无日志")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("当应用运行时，日志将显示在这里")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    // 底部操作栏
    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            // 复制按钮
            Button {
                copyLogs()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                    Text("复制")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            
            // 刷新按钮
            Button {
                logManager.loadTodayLog()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("刷新")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            
            // 清空按钮
            Button(role: .destructive) {
                logManager.clearTodayLog()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("清空")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // 复制日志
    private func copyLogs() {
        UIPasteboard.general.string = logManager.logContent
        withAnimation {
            showCopySuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopySuccess = false
            }
        }
    }
}

// Toast 提示视图
struct ToastView: View {
    let message: String
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .padding(.bottom, 100)
        }
    }
}
