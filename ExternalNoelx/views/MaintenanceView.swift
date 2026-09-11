import SwiftUI

struct MaintenanceView: View {
    @ObservedObject var manager: LicenseManager
    @State private var isRetrying = false
    @State private var checkTimer: Timer?
    @State private var lastCheckedAt = Date()
    @State private var autoRetryCountdown = 30
    @State private var autoRetryTimer: Timer?

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedHyperBackdrop()
                    .ignoresSafeArea()

                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer(minLength: 40)

                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 100, height: 100)
                                .blur(radius: 20)
                            Circle()
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 88, height: 88)
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                        .padding(.top, 20)

                        // Title
                        VStack(spacing: 8) {
                            Text("Under Maintenance")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)

                            Text("We'll be back shortly")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        // Message card
                        VStack(spacing: 14) {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.system(size: 16, weight: .bold))
                                Text("Server Message")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.75))
                                Spacer()
                            }

                            Text(manager.maintenanceMessage ?? "Server is under maintenance. Please try again later.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(18)
                        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 22)

                        // Last checked
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text("Last checked: \(timeAgo(from: lastCheckedAt))")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.45))

                        // Retry button
                        Button(action: retry) {
                            HStack(spacing: 10) {
                                if isRetrying {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                Text(isRetrying ? "CHECKING…" : "TRY AGAIN")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                            .shadow(color: AppTheme.accent.opacity(0.35), radius: 14, y: 7)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRetrying)
                        .padding(.horizontal, 22)

                        if autoRetryCountdown > 0 && !isRetrying {
                            Text("Auto-retry in \(autoRetryCountdown)s")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        // Divider
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.horizontal, 40)
                            .padding(.top, 8)

                        // Contact
                        VStack(spacing: 12) {
                            Text("Need help? Contact us")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))

                            HStack(spacing: 12) {
                                contactButton(
                                    title: "WhatsApp",
                                    icon: "message.fill",
                                    color: Color(red: 0.15, green: 0.83, blue: 0.38),
                                    url: manager.supportWhatsApp
                                )
                                contactButton(
                                    title: "Telegram",
                                    icon: "paperplane.fill",
                                    color: Color(red: 0.16, green: 0.63, blue: 0.87),
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
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startAutoRetry()
        }
        .onDisappear {
            stopAutoRetry()
        }
    }

    // MARK: - Contact Button

    private func contactButton(title: String, icon: String, color: Color, url: String) -> some View {
        Button {
            guard let destination = URL(string: url) else { return }
            UIApplication.shared.open(destination)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Retry

    private func retry() {
        isRetrying = true
        manager.retry()
        // Delay minimal biar ada feedback visual
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
