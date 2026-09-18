import SwiftUI

struct LicenseActivationView: View {
    @ObservedObject var manager: LicenseManager
    @EnvironmentObject private var remoteConfig: RemoteConfigService
    @State private var key = ""
    @FocusState private var keyFocused: Bool
    @State private var glowPulse = false
    @State private var borderPhase = false

    private var supportWhatsApp: String {
        remoteConfig.supportWhatsApp ?? manager.supportWhatsApp
    }

    private var supportTelegram: String {
        remoteConfig.supportTelegram ?? manager.supportTelegram
    }

    private var isDeviceSupported: Bool {
        manager.isDeviceSupported
    }

    var body: some View {
        ZStack {
            BP.bg.ignoresSafeArea()
            scanlineBackground

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 60)
                        logoSection
                        titleSection

                        // ═══ UNSUPPORTED BANNER ═══
                        if !isDeviceSupported {
                            unsupportedBanner
                                .padding(.horizontal, 22)
                                .padding(.top, 20)
                        }

                        activationCard
                            .padding(.horizontal, 22)
                            .padding(.top, 24)
                            .id("activation-card")

                        contactSection
                            .padding(.top, 22)
                            .padding(.horizontal, 22)
                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: keyFocused) { focused in
                    guard focused else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("activation-card", anchor: .center)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                borderPhase = true
            }
        }
    }

    // MARK: - Unsupported Banner

    private var unsupportedBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(BP.warning)
            VStack(alignment: .leading, spacing: 4) {
                Text("UNSUPPORTED DEVICE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(BP.warning)
                Text("iOS \(AppInfo.osVersion) is not supported.\nRequires iOS 17 or newer.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(BP.textDim)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(BP.warning.opacity(0.08))
        .overlay(
            Rectangle().stroke(BP.warning.opacity(0.4), lineWidth: 0.8)
        )
    }

    // MARK: - Scanline

    private var scanlineBackground: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            BP.accent.opacity(0.04),
                            BP.accent.opacity(0.08),
                            BP.accent.opacity(0.04),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 60)
                .offset(y: borderPhase ? proxy.size.height + 60 : -60)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // MARK: - Logo

    private var logoSection: some View {
        ZStack {
            Circle()
                .fill(BP.accent.opacity(0.18))
                .frame(width: 120, height: 120)
                .blur(radius: 30)
                .scaleEffect(glowPulse ? 1.15 : 0.95)

            Circle()
                .fill(BP.panelHi)
                .frame(width: 96, height: 96)
                .overlay(
                    Circle().stroke(BP.accent.opacity(0.55), lineWidth: 1.2)
                )

            AppLogo(size: 72)
        }
        .padding(.bottom, 22)
    }

    private var titleSection: some View {
        VStack(spacing: 6) {
            Text("EXTERNAL NIXX")
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .tracking(3.0)
                .foregroundStyle(BP.text)
                .shadow(color: BP.accentGlow, radius: 6)

            Text("LICENSE ACTIVATION")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2.5)
                .foregroundStyle(BP.accent)
        }
    }

    // MARK: - Activation Card

    private var activationCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Text("─ KEY ─")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(BP.accent.opacity(0.5))
                Spacer()
                Text(manager.isBusy ? "VERIFYING…" : "READY")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(manager.isBusy ? BP.warning : BP.accent)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 10) {
                Text("ENTER YOUR LICENSE KEY")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(BP.textFaint)

                TextField("NIXX-XXXX-XXXX-XXXX", text: $key)
                    .focused($keyFocused)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(activate)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(BP.text)
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(BP.bg)
                    .overlay(
                        Rectangle().stroke(
                            keyFocused ? BP.accent : BP.lineBright,
                            lineWidth: keyFocused ? 1.2 : 0.8
                        )
                    )
                    .id("license-field")
                    .disabled(!isDeviceSupported)

                Toggle("Remember on this device", isOn: $manager.rememberKey)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(BP.textDim)
                    .tint(BP.accent)
                    .disabled(!isDeviceSupported)

                Button(action: activate) {
                    HStack(spacing: 8) {
                        if manager.isBusy {
                            ProgressView().tint(BP.bg).scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 13, weight: .black))
                        }
                        Text(manager.isBusy ? "VERIFYING…" : "ACTIVATE")
                    }
                }
                .buttonStyle(BPButtonStyle(color: BP.accent, filled: true))
                .frame(maxWidth: .infinity, minHeight: 48)
                .disabled(!isDeviceSupported ||
                          key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          manager.isBusy)
                .opacity((!isDeviceSupported ||
                          key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.4 : 1.0)

                if let message = manager.message {
                    Text(message)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(messageColor(message))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(messageColor(message).opacity(0.10))
                        .overlay(
                            Rectangle().stroke(messageColor(message).opacity(0.5), lineWidth: 0.8)
                        )
                }
            }
            .padding(14)
            .padding(.bottom, 12)
        }
        .background(BP.panel)
        .overlay(Rectangle().stroke(BP.line, lineWidth: 0.5))
        .overlay(alignment: .leading) {
            Rectangle().fill(BP.accent).frame(width: 2)
        }
    }

    // MARK: - Contact

    private var contactSection: some View {
        VStack(spacing: 10) {
            Text("NEED HELP?")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(BP.textFaint)

            HStack(spacing: 8) {
                contactChip(
                    title: "WHATSAPP",
                    icon: "message.fill",
                    color: Color(red: 0.15, green: 0.83, blue: 0.38),
                    url: supportWhatsApp
                )
                contactChip(
                    title: "TELEGRAM",
                    icon: "paperplane.fill",
                    color: Color(red: 0.16, green: 0.63, blue: 0.87),
                    url: supportTelegram
                )
            }
        }
    }

    private func contactChip(title: String, icon: String, color: Color, url: String) -> some View {
        Button {
            guard let destination = URL(string: url) else { return }
            UIApplication.shared.open(destination)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(BP.text)
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(BP.panelHi)
            .overlay(Rectangle().stroke(color.opacity(0.5), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func activate() {
        guard isDeviceSupported else { return }
        keyFocused = false
        manager.activate(key: key)
    }

    private func messageColor(_ text: String) -> Color {
        let lower = text.lowercased()
        if lower.contains("activated") || lower.contains("active") || lower.contains("success") {
            return BP.success
        }
        if lower.contains("maintenance") || lower.contains("offline") {
            return BP.warning
        }
        if lower.contains("not supported") {
            return BP.warning
        }
        return BP.danger
    }
}
