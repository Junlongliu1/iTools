//
//  NutstoreLoginSheet.swift
//  坚果云登录面板
//

import SwiftUI

struct NutstoreLoginSheet: View {

    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var appPassword = ""
    @State private var isLoggingIn = false
    @State private var errorMessage: String?

    @FocusState private var focusField: Field?

    private enum Field { case email, password }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground),
                        Color(.secondarySystemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        introCard
                        formCard
                        helpCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
            .navigationTitle("登录坚果云")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(isLoggingIn)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoggingIn {
                        ProgressView()
                    } else {
                        Button("登录") { performLogin() }
                            .fontWeight(.semibold)
                            .disabled(!isValid)
                    }
                }
            }
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    focusField = .email
                }
            }
        }
    }

    private var isValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
        && !appPassword.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var introCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.65, blue: 0.35),
                                Color(red: 0.10, green: 0.50, blue: 0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: "cloud.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("使用坚果云账号登录")
                .font(.system(size: 16, weight: .semibold))

            Text("填写坚果云注册邮箱和 WebDAV 应用密码。\n凭证仅保存在本机 Keychain，不会上传到任何服务器。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private var formCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "at")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                TextField("坚果云账号邮箱", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 15))
                    .focused($focusField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusField = .password }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().padding(.leading, 52)

            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                SecureField("应用密码", text: $appPassword)
                    .textContentType(.password)
                    .font(.system(size: 15))
                    .focused($focusField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { if isValid { performLogin() } }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if let errorMessage {
                Divider().padding(.leading, 52)

                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)

                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
    }

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)

                Text("如何获取应用密码？")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                helpStep("1", "在浏览器中打开 jianguoyun.com 并登录")
                helpStep("2", "点击右上角头像 → 账户信息")
                helpStep("3", "选择「安全选项」→「添加应用密码」")
                helpStep("4", "输入名称（如 iTools），生成后复制")
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                Text("应用密码不是登录密码，可随时在网页端撤销")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    private func helpStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.blue, in: Circle())

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }

    private func performLogin() {
        guard isValid else { return }

        isLoggingIn = true
        errorMessage = nil
        focusField = nil

        Task { @MainActor in
            do {
                try await NutstoreAuth.shared.login(
                    email: email,
                    appPassword: appPassword
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch {
                isLoggingIn = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                withAnimation {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
