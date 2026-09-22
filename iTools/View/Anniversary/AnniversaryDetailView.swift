// AnniversaryDetailView.swift
//
//  iOS 26+ 原生 Liquid Glass 详情页
//
import SwiftUI
import SwiftData
import UIKit
import Accessibility

struct AnniversaryDetailView: View {
    let anniversary: Anniversary

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var pendingDelete = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard
                infoCard

                if !anniversary.notes.isEmpty {
                    notesCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(backgroundLayer.ignoresSafeArea())
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("编辑")

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("删除")
            }
        }
        .sheet(isPresented: $showEdit) {
            AnniversaryEditor(mode: .edit(anniversary))
        }
        .alert("删除纪念日？", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                pendingDelete = true
            }
        } message: {
            Text("将删除「\(anniversary.title)」，此操作不可撤销。")
        }
        .onChange(of: showDeleteConfirm) { _, isShowing in
            guard !isShowing, pendingDelete else { return }
            pendingDelete = false
            performDelete()
        }
        .alert("出错了", isPresented: errorBinding) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 背景（淡染分类色）

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                anniversary.category.topColor.opacity(0.16),
                anniversary.category.topColor.opacity(0.04),
                Color(.systemGroupedBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(Color(.systemGroupedBackground).opacity(0.35))
    }

    // MARK: - Hero 玻璃卡片

    private var heroCard: some View {
        VStack(spacing: 12) {
            Image(systemName: anniversary.category.symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(anniversary.category.topColor)

            Text(anniversary.title)
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(.primary)

            Text(heroCountdownText)
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(anniversary.category.topColor)
                .padding(.top, 2)

            Text(anniversary.gregorianDateText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
        .glassEffect(
            .regular.tint(anniversary.category.topColor.opacity(0.22)),
            in: .rect(cornerRadius: 28)
        )
    }

    private var heroCountdownText: String {
        switch anniversary.daysUntil {
        case 0:  return "今天"
        case 1:  return "明天"
        default: return "\(anniversary.daysUntil) 天后"
        }
    }

    // MARK: - 信息卡片

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(
                icon: anniversary.category.symbol,
                tint: anniversary.category.topColor,
                title: "分类",
                value: anniversary.category.title
            )

            divider

            infoRow(
                icon: "calendar",
                tint: Color(red: 0.36, green: 0.58, blue: 1.00),
                title: "原始日期",
                value: originalDateText
            )

            if anniversary.isYearly {
                divider
                infoRow(
                    icon: "arrow.triangle.2.circlepath",
                    tint: Color(red: 0.20, green: 0.70, blue: 0.45),
                    title: "下次发生",
                    value: anniversary.gregorianDateText
                )
            }

            if let lunar = anniversary.lunarDateText {
                divider
                infoRow(
                    icon: "moon.stars.fill",
                    tint: Color(red: 0.60, green: 0.40, blue: 0.85),
                    title: "农历",
                    value: lunar
                )
            }

            if anniversary.isYearly && anniversary.yearsCount > 0 {
                divider
                infoRow(
                    icon: "number.circle.fill",
                    tint: Color(red: 0.95, green: 0.55, blue: 0.20),
                    title: "周年",
                    value: "第 \(anniversary.yearsCount) 周年"
                )
            }

            divider

            infoRow(
                icon: "bell.fill",
                tint: Color(red: 1.00, green: 0.36, blue: 0.52),
                title: "提醒",
                value: anniversary.reminder.title
            )

            if anniversary.isPinned {
                divider
                infoRow(
                    icon: "pin.fill",
                    tint: Color(red: 0.95, green: 0.55, blue: 0.20),
                    title: "置顶",
                    value: "已置顶"
                )
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private var divider: some View {
        Divider().padding(.leading, 60)
    }

    private func infoRow(
        icon: String,
        tint: Color,
        title: String,
        value: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint)
                )

            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var originalDateText: String {
        let c = Anniversary.gregorianCalendar
        let y = c.component(.year, from: anniversary.date)
        let m = c.component(.month, from: anniversary.date)
        let d = c.component(.day, from: anniversary.date)
        return "\(y)年\(m)月\(d)日"
    }

    // MARK: - 备注卡片

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("备注", systemImage: "note.text")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(anniversary.notes)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: - 删除逻辑

    private func performDelete() {
        let title = anniversary.title
        ReminderScheduler.cancel(anniversary)

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            context.delete(anniversary)
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            AppLogError("删除纪念日失败 [\(title)]: \(error.localizedDescription)")
            errorMessage = "操作失败：\(error.localizedDescription)"
            return
        }

        AccessibilityNotification.Announcement("已删除 \(title)").post()
        dismiss()
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
