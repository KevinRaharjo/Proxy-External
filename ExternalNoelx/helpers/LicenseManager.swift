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

    /// Support & contact channels (tampil di maintenance & activation view)
    let supportWhatsApp = "https://wa.me/6281234567890"       // GANTI NOMOR WA KAMU
    let supportTelegram = "https://t.me/nixxtime"              // GANTI USERNAME TELEGRAM KAMU

    // MARK: - Storage

    private enum StorageKeys {
        static let licenseKey = "com.nixxtime.license_key"
        static let sessionToken = "com.nixxtime.session_token"
        static let lastVerified = "com.nixxtime.last_verified"
        static let cachedExpiry = "com.nixxtime.cached_expiry"
        static let maintenanceMessage = "com.nixxtime.maintenance_message"
    }

    /// Grace period saat offline (24 jam).
    private let offlineGracePeriod: TimeInterval = 24 * 60 * 60
    /// Rate limit local attempt (detik).
    private let minimumAttemptInterval: TimeInterval = 1.0

    private var lastAttemptAt: Date?

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

    // MARK: - Launch

    func beginLaunchSession() {
        // Kalau tidak ada token tersimpan → langsung inactive
        guard let token = UserDefaults.standard.string(forKey: StorageKeys.sessionToken),
              UserDefaults.standard.string(forKey: StorageKeys.licenseKey) != nil else {
            state = .inactive
            message = "Enter your license key to continue"
            return
        }

        state = .checking
        isBusy = true
        message = "Verifying license…"

        Task {
            do {
                // 1. Cek status server
                let status = try await APIClient.shared.status()

                if status.maintenance {
                    let msg = status.message ?? "Server is under maintenance. Please try again later."
                    UserDefaults.standard.set(msg, forKey: StorageKeys.maintenanceMessage)
                    await MainActor.run {
                        self.isBusy = false
                        self.state = .maintenance(message: msg)
                        self.message = msg
                    }
                    return
                }

                // 2. Verify token
                let response = try await APIClient.shared.verify(
                    token: token,
                    deviceID: deviceID
                )

                await MainActor.run {
                    self.isBusy = false
                    if response.success {
                        self.state = .active
                        self.expirationDate = response.expiresAt
                        self.message = "License active"
                        UserDefaults.standard.set(Date(), forKey: StorageKeys.lastVerified)
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
                    self.handleMaintenanceOrOffline(error: error)
                }
            } catch {
                await MainActor.run {
                    self.handleMaintenanceOrOffline(error: APIClientError.networkUnreachable)
                }
            }
        }
    }

    // MARK: - Activate

    func activate(key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else { return }

        // Rate limit
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
                log("license: deactivate failed offline, clearing local only")
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
        expirationDate = nil
    }

    private func handleMaintenanceOrOffline(error: APIClientError) {
        isBusy = false

        // Cek maintenance
        if case .maintenance(let msg) = error {
            state = .maintenance(message: msg)
            message = msg
            return
        }

        // Offline fallback
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
        let bundle = Bundle.main.bundleIdentifier ?? "com.kevin.nixxtime"
        let raw = "\(idfv)|\(bundle)"
        let hash = SHA256.hash(data: Data(raw.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
