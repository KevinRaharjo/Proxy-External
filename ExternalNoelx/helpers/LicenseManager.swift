import Combine
import Foundation
import UIKit
import CryptoKit

@MainActor
final class LicenseManager: ObservableObject {

    enum LicenseState: Equatable {
        case checking
        case active
        case inactive
        case maintenance(message: String)
        case offline
    }

    @Published private(set) var state: LicenseState = .checking
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    @Published private(set) var expirationDate: Date?
    @Published private(set) var deviceID: String = ""
    @Published var rememberKey = true

    let supportWhatsApp = "https://wa.me/6281234567890"
    let supportTelegram = "https://t.me/nixxtime"

    private enum StorageKeys {
        static let licenseKey = "com.nixxtime.license_key"
        static let sessionToken = "com.nixxtime.session_token"
        static let lastVerified = "com.nixxtime.last_verified"
        static let cachedExpiry = "com.nixxtime.cached_expiry"
        static let maintenanceMessage = "com.nixxtime.maintenance_message"
        static let lastForegroundVerify = "com.nixxtime.last_foreground_verify"
    }

    private let offlineGracePeriod: TimeInterval = 24 * 60 * 60
    private let foregroundReverifyInterval: TimeInterval = 3600
    private let minimumAttemptInterval: TimeInterval = 1.0

    private var lastAttemptAt: Date?
    private var isVerifying = false

    init() {
        deviceID = Self.computeDeviceID()
        state = .checking
    }

    var isActive: Bool {
        if case .active = state { return true }
        return false
    }

    var isMaintenance: Bool {
        if case .maintenance = state { return true }
        return false
    }

    var maintenanceMessage: String? {
        if case .maintenance(let msg) = state { return msg }
        return nil
    }

    // MARK: - Device Support Check (SYNC)

    /// Cek device support pake data yang udah ada (sync, cepat).
    /// Pake ini buat UI rendering. Buat logic penting, pake `isDeviceSupportedAsync()`.
    var isDeviceSupported: Bool {
        let v = AppInfo.versionTuple
        return ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
    }

    // MARK: - Device Support Check (ASYNC, RECOMMENDED)

    /// Cek device support pake server data (async, akurat).
    /// Panggil ini di launch session biar server data udah ke-load.
    func isDeviceSupportedAsync() async -> Bool {
        let v = AppInfo.versionTuple
        return await ExploitSupportPolicy.isSupportedAsync(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
    }

    // MARK: - Foreground Guard

    func shouldReverifyOnForeground() -> Bool {
        if !isActive { return true }
        if isVerifying { return false }

        let last = UserDefaults.standard.object(forKey: StorageKeys.lastForegroundVerify) as? Date
            ?? .distantPast
        let elapsed = Date().timeIntervalSince(last)

        if elapsed >= foregroundReverifyInterval {
            UserDefaults.standard.set(Date(), forKey: StorageKeys.lastForegroundVerify)
            return true
        }
        return false
    }

    // MARK: - Launch (ASYNC, server-first)

    func beginLaunchSession() {
        // ═══ CEK DEVICE SUPPORT DULU (server-first) ═══
        Task {
            // Fetch server dulu biar SupportedVersionsStore ke-populate
            await SupportedVersionsService.shared.ensureLoaded()

            let supported = await isDeviceSupportedAsync()
            guard supported else {
                await MainActor.run {
                    self.state = .inactive
                    self.message = "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) is not supported. Please use a supported version."
                }
                return
            }

            // Sekarang lanjut verify license
            await self.performLaunchVerification()
        }
    }

    private func performLaunchVerification() async {
        guard let token = UserDefaults.standard.string(forKey: StorageKeys.sessionToken),
              UserDefaults.standard.string(forKey: StorageKeys.licenseKey) != nil else {
            state = .inactive
            message = "Enter your license key to continue"
            return
        }

        if isVerifying { return }

        if case .active = state,
           let lastVerified = UserDefaults.standard.object(forKey: StorageKeys.lastVerified) as? Date,
           Date().timeIntervalSince(lastVerified) < 300 {
            return
        }

        let wasActive = isActive

        if !wasActive {
            state = .checking
        }
        isBusy = true
        isVerifying = true
        message = "Verifying license…"

        do {
            let status = try await APIClient.shared.status()

            if status.maintenance {
                let msg = status.message ?? "Server is under maintenance. Please try again later."
                UserDefaults.standard.set(msg, forKey: StorageKeys.maintenanceMessage)
                self.isBusy = false
                self.isVerifying = false
                self.state = .maintenance(message: msg)
                self.message = msg
                return
            }

            let response = try await APIClient.shared.verify(token: token, deviceID: deviceID)

            self.isBusy = false
            self.isVerifying = false
            if response.success {
                self.state = .active
                self.expirationDate = response.expiresAt
                self.message = "License active"
                UserDefaults.standard.set(Date(), forKey: StorageKeys.lastVerified)
                UserDefaults.standard.set(Date(), forKey: StorageKeys.lastForegroundVerify)
                if let expiry = response.expiresAt {
                    UserDefaults.standard.set(expiry, forKey: StorageKeys.cachedExpiry)
                }
            } else {
                self.clearSession()
                self.state = .inactive
                self.message = response.error ?? "Session expired. Please activate again."
            }
        } catch let error as APIClientError {
            self.isBusy = false
            self.isVerifying = false
            self.handleMaintenanceOrOffline(error: error, wasActive: wasActive)
        } catch {
            self.isBusy = false
            self.isVerifying = false
            self.handleMaintenanceOrOffline(error: APIClientError.networkUnreachable, wasActive: wasActive)
        }
    }

    // MARK: - Activate

    func activate(key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else { return }

        // ═══ CEK DEVICE SUPPORT (server-first) ═══
        Task {
            await SupportedVersionsService.shared.ensureLoaded()

            let supported = await isDeviceSupportedAsync()
            guard supported else {
                await MainActor.run {
                    self.message = "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) is not supported."
                    self.state = .inactive
                }
                return
            }

            await self.performActivation(key: trimmed)
        }
    }

    private func performActivation(key: String) async {
        if let last = lastAttemptAt, Date().timeIntervalSince(last) < minimumAttemptInterval {
            message = "Please wait a moment before trying again"
            return
        }
        lastAttemptAt = Date()

        isBusy = true
        message = "Checking license key…"

        let device = LicenseDeviceInfo(
            deviceID: deviceID,
            deviceName: UIDevice.current.name,
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion
        )

        do {
            let response = try await APIClient.shared.activate(key: key, device: device)

            self.isBusy = false
            if response.success, let token = response.token {
                self.state = .active
                self.expirationDate = response.expiresAt
                self.message = "Activated successfully"

                if self.rememberKey {
                    UserDefaults.standard.set(key, forKey: StorageKeys.licenseKey)
                    UserDefaults.standard.set(token, forKey: StorageKeys.sessionToken)
                    UserDefaults.standard.set(Date(), forKey: StorageKeys.lastVerified)
                    UserDefaults.standard.set(Date(), forKey: StorageKeys.lastForegroundVerify)
                    if let expiry = response.expiresAt {
                        UserDefaults.standard.set(expiry, forKey: StorageKeys.cachedExpiry)
                    }
                }
            } else {
                self.state = .inactive
                self.message = response.error ?? "Invalid key"
            }
        } catch let error as APIClientError {
            self.isBusy = false
            if case .maintenance(let msg) = error {
                self.state = .maintenance(message: msg)
                self.message = msg
            } else {
                self.state = .inactive
                self.message = error.localizedDescription
            }
        } catch {
            self.isBusy = false
            self.state = .inactive
            self.message = "Unknown error"
        }
    }

    // MARK: - Deactivate

    func deactivate() {
        guard let token = UserDefaults.standard.string(forKey: StorageKeys.sessionToken) else {
            clearSession()
            state = .inactive
            message = "Deactivated"
            return
        }

        isBusy = true
        message = "Deactivating…"

        Task {
            do {
                _ = try await APIClient.shared.deactivate(token: token, deviceID: deviceID)
            } catch {
                // Ignore offline error
            }
            self.clearSession()
            self.isBusy = false
            self.state = .inactive
            self.message = "Deactivated from this device"
        }
    }

    // MARK: - Retry / Refresh

    func retry() { beginLaunchSession() }
    func refresh() { beginLaunchSession() }

    // MARK: - Remembered Key

    func rememberedKey() -> String? {
        UserDefaults.standard.string(forKey: StorageKeys.licenseKey)
    }

    var hasSavedKey: Bool {
        UserDefaults.standard.string(forKey: StorageKeys.sessionToken) != nil
    }

    // MARK: - Helpers

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: StorageKeys.licenseKey)
        UserDefaults.standard.removeObject(forKey: StorageKeys.sessionToken)
        UserDefaults.standard.removeObject(forKey: StorageKeys.lastVerified)
        UserDefaults.standard.removeObject(forKey: StorageKeys.cachedExpiry)
        UserDefaults.standard.removeObject(forKey: StorageKeys.lastForegroundVerify)
        expirationDate = nil
    }

    private func handleMaintenanceOrOffline(error: APIClientError, wasActive: Bool) {
        if case .maintenance(let msg) = error {
            state = .maintenance(message: msg)
            message = msg
            return
        }

        if wasActive {
            state = .active
            message = "Offline mode"
            return
        }

        guard let lastVerified = UserDefaults.standard.object(forKey: StorageKeys.lastVerified) as? Date else {
            state = .inactive
            message = "Cannot verify license. Check your connection."
            return
        }

        let elapsed = Date().timeIntervalSince(lastVerified)
        if elapsed < offlineGracePeriod {
            state = .active
            expirationDate = UserDefaults.standard.object(forKey: StorageKeys.cachedExpiry) as? Date
            let hoursLeft = Int((offlineGracePeriod - elapsed) / 3600)
            message = "Offline mode (\(hoursLeft)h remaining)"
        } else {
            state = .inactive
            message = "Offline session expired. Connect to internet to verify."
        }
    }

    // MARK: - Device ID

    private static func computeDeviceID() -> String {
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let bundle = Bundle.main.bundleIdentifier ?? "com.apple.mobile.MobileHouseArrest"
        let raw = "\(idfv)|\(bundle)"
        let hash = SHA256.hash(data: Data(raw.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
