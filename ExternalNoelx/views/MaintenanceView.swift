import SwiftUI

struct MaintenanceView: View {
    @ObservedObject var manager: LicenseManager
    @State private var isRetrying = false
    @State private var lastCheckedAt = Date()
    @State private var autoRetryCountdown = 30
    @State private var autoRetryTimer: Timer?
    @State private var pulsePhase = false

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedHyperBackdrop()

                Color.black.opacity(0.35).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer(minLength: 40)

                        // ─── Icon with glow pulse ─────────────────────
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.18))
                                .frame(width: 120, height: 120)
                                .blur(radius: 30)
                                .scaleEffect(pulsePhase ? 1.15 : 0.95)

                            Circle()
                                .fill(AppTheme.surfaceElevated)
                                .frame(width: 96, height: 96)
                                .overlay(
                                    Circle()
                                        .stroke(AppTheme.accent.opacity(0.55), lineWidth: 1.2)
                                )
                                .shadow(color: AppTheme.accentGlow, radius: 18)

                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundStyle(AppTheme.accentBright)
                        }
                        .padding(.top, 20)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                                pulsePhase = true
                            }
                        }

                        // ─── Title ─────────────────────────────────────
                        VStack(spacing: 8) {
                            Text("Under Maintenance")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(AppTheme.silverGradient)
                                .shadow(color: AppTheme.accentGlow, radius: 6)
                                .multilineTextAlignment(.center)

                            Text("We'll be back shortly")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(AppTheme.silverDim)
                        }

                        // ─── Message card ─────────────────────────────
                        AppSurfaceCard(
                            corner: AppTheme.cardCorner,
                            glowColor: AppTheme.accent,
                            glowActive: true
                        ) {
                            VStack(spacing: 14) {
                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundStyle(AppTheme.accentBright)
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Server Message")
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                        .tracking(0.8)
                                        .foregroundStyle(AppTheme.silverDim)
                                    Spacer()
                                }

                                Text(manager.maintenanceMessage ?? "Server is under maintenance. Please try again later.")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppTheme.silver)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(.horizontal, 22)

                        // ─── Last checked ─────────────────────────────
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Last checked: \(timeAgo(from: lastCheckedAt))")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(AppTheme.silverMuted)

                        // ─── Retry button ─────────────────────────────
                        Button(action: retry) {
                            HStack(spacing: 10) {
                                if isRetrying {
                                    ProgressView()
                                        .tint(AppTheme.silverBright)
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                Text(isRetrying ? "CHECKING…" : "TRY AGAIN")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .tracking(0.8)
                            }
                        }
                        .buttonStyle(AppPrimaryButtonStyle(tint: AppTheme.accent, fullWidth: true))
                        .disabled(isRetrying)
                        .padding(.horizontal, 22)
                        .glowPulse(active: !isRetrying, color: AppTheme.accent)

                        if autoRetryCountdown > 0 && !isRetrying {
                            Text("Auto-retry in \(autoRetryCountdown)s")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.silverMuted)
                        }

                        // ─── Divider ──────────────────────────────────
                        Rectangle()
                            .fill(AppTheme.borderSubtle)
                            .frame(height: 0.8)
                            .padding(.horizontal, 40)
                            .padding(.top, 10)

                        // ─── Contact ──────────────────────────────────
                        VStack(spacing: 14) {
                            Text("Need help? Contact us")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.silverMuted)

                            HStack(spacing: 12) {
                                contactButton(
                                    title: "WhatsApp",
                                    icon: "message.fill",
                                    tint: AppTheme.success,
                                    url: manager.supportWhatsApp
                                )
                                contactButton(
                                    title: "Telegram",
                                    icon: "paperplane.fill",
                                    tint: AppTheme.accentBright,
                                    url: manager.supportTelegram
                                )
                            }
                            .padding(.horizontal, 22)
                        }

                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear { startAutoRetry() }
            .onDisappear { stopAutoRetry() }
        }
    }

    // MARK: - Contact Button

    private func contactButton(title: String, icon: String, tint: Color, url: String) -> some View {
        Button {
            guard let destination = URL(string: url) else { return }
            UIApplication.shared.open(destination)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.silver)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(0.45), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Retry

    private func retry() {
        isRetrying = true
        manager.retry()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isRetrying = false
            lastCheckedAt = Date()
            resetAutoRetry()
        }
    }

    // MARK: - Auto Retry

    private func startAutoRetry() {
        autoRetryCountdown = 30
        autoRetryTimer?.invalidate()
        autoRetryTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if autoRetryCountdown > 1 {
                autoRetryCountdown -= 1
            } else {
                timer.invalidate()
                retry()
            }
        }
    }

    private func resetAutoRetry() {
        autoRetryTimer?.invalidate()
        startAutoRetry()
    }

    private func stopAutoRetry() {
        autoRetryTimer?.invalidate()
        autoRetryTimer = nil
    }

    // MARK: - Time Ago

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
    }
}
