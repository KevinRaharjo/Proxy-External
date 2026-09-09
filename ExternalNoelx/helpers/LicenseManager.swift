import Combine
import Foundation

@MainActor
final class LicenseManager: ObservableObject {
    static let accessKey = "Noelx"

    @Published private(set) var expirationDate: Date?
    @Published private(set) var isActive = false
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    @Published private(set) var contactOwner: String?
    @Published var rememberKey = true

    private let userDefaultsKey = "com.noelx.external-ios.license_key"
    private var lastAttemptAt: Date?

    init() {
        isActive = hasSavedKey
    }

    var hasSavedKey: Bool {
        UserDefaults.standard.string(forKey: userDefaultsKey) == Self.accessKey
    }

    func beginLaunchSession() {
        isActive = hasSavedKey
        message = isActive ? "Ready to use" : "Key required — enter your access key"
    }

    func activate(key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else { return }
        if let lastAttemptAt, Date().timeIntervalSince(lastAttemptAt) < 1 {
            message = "Please wait a moment before trying again"
            return
        }
        lastAttemptAt = Date()
        isBusy = true
        message = "Checking access key…"

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isBusy = false
            guard trimmed == Self.accessKey else {
                self.isActive = false
                self.message = "Invalid access key"
                return
            }
            if self.rememberKey {
                UserDefaults.standard.set(Self.accessKey, forKey: self.userDefaultsKey)
            }
            self.isActive = true
            self.message = "Activated successfully"
        }
    }

    func rememberedKey() -> String? {
        UserDefaults.standard.string(forKey: userDefaultsKey)
    }

    func refresh() {
        isActive = hasSavedKey
        message = isActive ? "Ready to use" : "Key required — enter your access key"
    }

    func deactivate() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        isActive = false
        message = "Activation removed from this device"
    }
    
    // Reset license - panggil ini kalo mau reset manual
    func resetLicense() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        isActive = false
        message = "License reset successfully"
    }
}
