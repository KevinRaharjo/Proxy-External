import Foundation
import Combine
import SwiftUI

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Models
// ═══════════════════════════════════════════════════════════════════════

struct RemoteConfig: Codable {
    let minAppVersion: String?
    let forceUpdateUrl: String?
    let maintenanceBanner: String?
    let supportWhatsapp: String?
    let supportTelegram: String?
    let featureWallpaperLab: Bool?
    let featureCleaner: Bool?
    let featurePatchSync: Bool?
    let featureOnboardingV2: Bool?
    let announcementBannerEnabled: Bool?
    let autoHeartbeatSeconds: Int?
    let patchSyncIntervalSeconds: Int?
    let welcomeMessage: String?

    enum CodingKeys: String, CodingKey {
        case minAppVersion = "min_app_version"
        case forceUpdateUrl = "force_update_url"
        case maintenanceBanner = "maintenance_banner"
        case supportWhatsapp = "support_whatsapp"
        case supportTelegram = "support_telegram"
        case featureWallpaperLab = "feature_wallpaper_lab"
        case featureCleaner = "feature_cleaner"
        case featurePatchSync = "feature_patch_sync"
        case featureOnboardingV2 = "feature_onboarding_v2"
        case announcementBannerEnabled = "announcement_banner_enabled"
        case autoHeartbeatSeconds = "auto_heartbeat_seconds"
        case patchSyncIntervalSeconds = "patch_sync_interval_seconds"
        case welcomeMessage = "welcome_message"
    }
}

struct RemoteConfigResponse: Codable {
    let success: Bool
    let config: RemoteConfig
    let fetchedAt: String?
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Service
// ═══════════════════════════════════════════════════════════════════════

@MainActor
final class RemoteConfigService: ObservableObject {
    static let shared = RemoteConfigService()

    @Published private(set) var config: RemoteConfig?
    @Published private(set) var lastFetch: Date?
    @Published private(set) var isLoading = false

    private let baseURL = URL(string: "https://api.proxynixx.my.id/")!
    private let cacheKey = "remote_config_cache"
    private let lastFetchKey = "remote_config_last_fetch"
    private let cacheTTL: TimeInterval = 300  // 5 menit

    private init() {
        loadFromCache()
    }

    // MARK: - Fetch

    func fetch(force: Bool = false) async {
        if !force,
           let lastFetch,
           Date().timeIntervalSince(lastFetch) < cacheTTL,
           config != nil {
            log("remote-config: using cache")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/config"))
            request.httpMethod = "GET"
            request.setValue("NixxTime-iOS/1.0", forHTTPHeaderField: "User-Agent")
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                log("remote-config: HTTP error")
                return
            }

            let decoded = try JSONDecoder().decode(RemoteConfigResponse.self, from: data)
            guard decoded.success else {
                log("remote-config: server returned success=false")
                return
            }

            config = decoded.config
            lastFetch = Date()
            saveToCache()
            log("remote-config: fetched successfully")
        } catch {
            log("remote-config: fetch failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Convenience Getters

    var minAppVersion: String {
        config?.minAppVersion ?? "1.0.0"
    }

    var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var isForceUpdateRequired: Bool {
        compareVersions(currentAppVersion, minAppVersion) < 0
    }

    var forceUpdateUrl: URL? {
        guard let url = config?.forceUpdateUrl, !url.isEmpty else { return nil }
        return URL(string: url)
    }

    var isWallpaperLabEnabled: Bool {
        config?.featureWallpaperLab ?? true
    }

    var isCleanerEnabled: Bool {
        config?.featureCleaner ?? true
    }

    var isPatchSyncEnabled: Bool {
        config?.featurePatchSync ?? true
    }

    var isOnboardingV2Enabled: Bool {
        config?.featureOnboardingV2 ?? false
    }

    var isAnnouncementBannerEnabled: Bool {
        config?.announcementBannerEnabled ?? true
    }

    var heartbeatInterval: TimeInterval {
        TimeInterval(config?.autoHeartbeatSeconds ?? 900)
    }

    var patchSyncInterval: TimeInterval {
        TimeInterval(config?.patchSyncIntervalSeconds ?? 3600)
    }

    var maintenanceBanner: String? {
        let msg = config?.maintenanceBanner ?? ""
        return msg.isEmpty ? nil : msg
    }

    var welcomeMessage: String? {
        let msg = config?.welcomeMessage ?? ""
        return msg.isEmpty ? nil : msg
    }

    var supportWhatsApp: String? {
        config?.supportWhatsapp
    }

    var supportTelegram: String? {
        config?.supportTelegram
    }

    // MARK: - Cache

    private func saveToCache() {
        guard let config else { return }
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: lastFetchKey)
        }
    }

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(RemoteConfig.self, from: data) else {
            return
        }
        config = cached
        lastFetch = UserDefaults.standard.object(forKey: lastFetchKey) as? Date
        log("remote-config: loaded from cache")
    }

    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: lastFetchKey)
        config = nil
        lastFetch = nil
    }

    // MARK: - Helpers

    private func compareVersions(_ a: String, _ b: String) -> Int {
        let pa = a.split(separator: ".").compactMap { Int($0) }
        let pb = b.split(separator: ".").compactMap { Int($0) }
        let len = max(pa.count, pb.count)
        for i in 0..<len {
            let va = i < pa.count ? pa[i] : 0
            let vb = i < pb.count ? pb[i] : 0
            if va != vb { return va - vb }
        }
        return 0
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Force Update View
// ═══════════════════════════════════════════════════════════════════════

struct ForceUpdateView: View {
    let message: String
    let updateURL: URL?

    var body: some View {
        ZStack {
            AnimatedHyperBackdrop()
                .ignoresSafeArea()

            Color.black.opacity(0.35).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)

                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.18))
                            .frame(width: 120, height: 120)
                            .blur(radius: 30)

                        Circle()
                            .fill(AppTheme.surfaceElevated)
                            .frame(width: 96, height: 96)
                            .overlay(
                                Circle().stroke(AppTheme.accent.opacity(0.55), lineWidth: 1.2)
                            )

                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(AppTheme.accentBright)
                    }

                    VStack(spacing: 10) {
                        Text("UPDATE REQUIRED")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(AppTheme.silverGradient)

                        Text(message)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.silverDim)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    if let updateURL {
                        Button {
                            UIApplication.shared.open(updateURL)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 16, weight: .bold))
                                Text("UPDATE NOW")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .tracking(1.0)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AppTheme.accent)
                            )
                            .shadow(color: AppTheme.accentGlow, radius: 12)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 32)
                    }

                    Text("Please update to the latest version to continue using External Nixx.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.silverMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer(minLength: 60)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
