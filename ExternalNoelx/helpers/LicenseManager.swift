import Combine
import Foundation
import UIKit
import CryptoKit

@MainActor
final class LicenseManager: ObservableObject {

    // MARK: - State

    enum LicenseState: Equatable {
        case checking
        case active
        case inactive
        case maintenance(message: String)
        case offline
    }

    // MARK: - Published State

    @Published private(set) var state: LicenseState = .checking
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    @Published private(set) var expirationDate: Date?
    @Published private(set) var deviceID: String = ""
    @Published var rememberKey = true

    // MARK: - Config

    let supportWhatsApp = "https://wa.me/6281234567890"
    let supportTelegram = "https://t.me/nixxtime"

    // MARK: - Storage

    private enum StorageKeys {
        static let licenseKey = "com.nixxtime.license_key"
        static let sessionToken = "com.nixxtime.session_token"
        static let lastVerified = "com.nixxtime.last_verified"
        static let cachedExpiry = "com.nixxtime.cached_expiry"
        static let maintenanceMessage = "com.nixxtime.maintenance_message"
        static let lastForegroundVerify = "com.nixxtime.last_foreground_verify"
    }

    private let offlineGracePeriod: TimeInterval = 24 * 60 * 60
    private let foregroundReverifyInterval: TimeInterval = 3600 // 1 jam
    private let minimumAttemptInterval: TimeInterval = 1.0

    private var lastAttemptAt: Date?
    private var isVerifying = false

    // MARK: - Init

    init() {
        deviceID = Self.computeDeviceID()
        state = .checking
    }

    // MARK: - Convenience

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

    // MARK: - Foreground Guard

    /// Cek apakah perlu re-verify saat app masuk foreground.
    /// Return true hanya kalau lisensi belum aktif ATAU sudah 1 jam sejak verify terakhir.
    func shouldReverifyOnForeground() -> Bool {
        // Kalau belum aktif (baru buka / logout) → selalu verify
        if !isActive {
            return true
        }

        // Kalau sedang verify → jangan verify lagi
        if isVerifying {
            return false
        }

        // Cek waktu verify terakhir
        let last = UserDefaults.standard.object(forKey: StorageKeys.lastForegroundVerify) as? Date
            ?? .distantPast
        let elapsed = Date().timeIntervalSince(last)

        if elapsed >= foregroundReverifyInterval {
            UserDefaults.standard.set(Date(), forKey: StorageKeys.lastForegroundVerify)
            return true
        }

        return false
    }

    // MARK: - Launch

    func beginLaunchSession() {
        guard let token = UserDefaults.standard.string(forKey: StorageKeys.sessionToken),
              UserDefaults.standard.string(forKey: StorageKeys.licenseKey) != nil else {
            state = .inactive
            message = "Enter your license key to continue"
            return
        }

        // Kalau sedang verify, jangan spawn task baru
        if isVerifying {
            return
        }

        // Kalau sudah active dan verify < 5 menit lalu, skip
        if case .active = state,
           let lastVerified = UserDefaults.standard.object(forKey: StorageKeys.lastVerified) as? Date,
           Date().timeIntervalSince(lastVerified) < 300 {
            return
        }

        // Kalau state bukan active, tampilkan loading
        // Kalau sudah active, jangan set checking — verify di background saja
        let wasActive = isActive

        if !wasActive {
            state = .checking
        }
        isBusy = true
        isVerifying = true
        message = "Verifying license…"

        Task {
            do {
                let status = try await APIClient.shared.status()

                if status.maintenance {
                    let msg = status.message ?? "Server is under maintenance. Please try again later."
                    UserDefaults.standard.set(msg, forKey: StorageKeys.maintenanceMessage)
                    await MainActor.run {
                        self.isBusy = false
                        self.isVerifying = false
                        self.state = .maintenance(message: msg)
                        self.message = msg
                    }
                    return
                }

                let response = try await APIClient.shared.verify(
                    token: token,
                    deviceID: deviceID
                )

                await MainActor.run {
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
                }
            } catch let error as APIClientError {
                await MainActor.run {
                    self.isBusy = false
                    self.isVerifying = false
                    self.handleMaintenanceOrOffline(error: error, wasActive: wasActive)
                }
            } catch {
                await MainActor.run {
                    self.isBusy = false
                    self.isVerifying = false
                    self.handleMaintenanceOrOffline(error: APIClientError.networkUnreachable, wasActive: wasActive)
                }
            }
        }
    }

    // MARK: - Activate

    func activate(key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else { return }

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

        Task {
            do {
                let response = try await APIClient.shared.activate(
                    key: trimmed,
                    device: device
                )

                await MainActor.run {
                    self.isBusy = false
                    if response.success, let token = response.token {
                        self.state = .active
                        self.expirationDate = response.expiresAt
                        self.message = "Activated successfully"

                        if self.rememberKey {
                            UserDefaults.standard.set(trimmed, forKey: StorageKeys.licenseKey)
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
                }
            } catch let error as APIClientError {
                await MainActor.run {
                    self.isBusy = false
                    if case .maintenance(let msg) = error {
                        self.state = .maintenance(message: msg)
                        self.message = msg
                    } else {
                        self.state = .inactive
                        self.message = error.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    self.isBusy = false
                    self.state = .inactive
                    self.message = "Unknown error"
                }
            }
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
                _ = try await APIClient.shared.deactivate(
                    token: token,
                    deviceID: deviceID
                )
            } catch {
                // Ignore offline error
            }
            await MainActor.run {
                self.clearSession()
                self.isBusy = false
                self.state = .inactive
                self.message = "Deactivated from this device"
            }
        }
    }

    // MARK: - Retry (untuk maintenance)

    func retry() {
        beginLaunchSession()
    }

    // MARK: - Refresh

    func refresh() {
        beginLaunchSession()
    }

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
        // Cek maintenance
        if case .maintenance(let msg) = error {
            state = .maintenance(message: msg)
            message = msg
            return
        }

        // Kalau sebelumnya sudah active, jangan reset ke inactive — biarkan tetap active
        if wasActive {
            state = .active
            message = "Offline mode"
            return
        }

        // Cek grace period offline
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
