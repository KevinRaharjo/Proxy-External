import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseManager: LicenseManager
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @AppStorage("selected_target") private var selectedTarget = "freefireth"

    @State private var showResetAlert = false
    @State private var resetMessage = ""
    @State private var showRestartAlert = false
    @State private var showResultAlert = false
    @State private var showDeactivateAlert = false

    var body: some View {
        NavigationStack {
            Form {
                appInfoSection
                targetGameSection
                languageSection
                deviceSection
                licenseSection
                versionSupportSection
                dangerZoneSection
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(language.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("common.done")) { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.accentBright)
                }
            }
            .alert("Reset Patches", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) { performResetPatches() }
            } message: {
                Text("This will remove all patch backups and reset patch states. Are you sure?")
            }
            .alert("Reset All Data", isPresented: $showRestartAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) { performResetAllData() }
            } message: {
                Text("This will remove everything including license, patches, and all data. Are you sure?")
            }
            .alert("Deactivate License", isPresented: $showDeactivateAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Deactivate", role: .destructive) { licenseManager.deactivate() }
            } message: {
                Text("Are you sure you want to remove the activation from this device? You can re-activate with the same key on another device.")
            }
            .alert("Result", isPresented: $showResultAlert) {
                Button("OK") { resetMessage = "" }
            } message: {
                Text(resetMessage)
            }
        }
    }

    @ViewBuilder
    private var appInfoSection: some View {
        Section {
            HStack(spacing: 14) {
                AppLogo(size: 46)
                VStack(alignment: .leading, spacing: 4) {
                    Text("External Nixx")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.silver)
                    Text(language.text("common.version", appVersion))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.silverDim)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .listRowBackground(AppTheme.surface)
        }
    }

    @ViewBuilder
    private var targetGameSection: some View {
        Section {
            Picker("Target Game", selection: $selectedTarget) {
                Text("FF Normal").tag("freefireth")
                Text("FF Max").tag("freefiremax")
            }
            .pickerStyle(.segmented)
            .listRowBackground(AppTheme.surface)
        } header: {
            Text("Target Game").foregroundStyle(AppTheme.accentBright)
        } footer: {
            Text("Choose the game you want to patch. Patches will load based on the selected target.")
                .foregroundStyle(AppTheme.silverDim)
        }
    }

    @ViewBuilder
    private var languageSection: some View {
        Section(language.text("settings.language")) {
            Picker(language.text("settings.language"), selection: $languageCode) {
                ForEach(AppLanguage.allCases) { option in
                    Text(option.displayName).tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .listRowBackground(AppTheme.surface)
        }
    }

    @ViewBuilder
    private var deviceSection: some View {
        Section(language.text("common.device")) {
            LabeledContent(
                language.text("dashboard.hardware_model"),
                value: AppInfo.displayMachineName
            )
            LabeledContent(
                language.text("settings.ios_version"),
                value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))"
            )
            LabeledContent("Device ID") { deviceIDText }
        }
    }

    @ViewBuilder
    private var deviceIDText: some View {
        let rawID: String = licenseManager.deviceID
        let shortID: String = String(rawID.prefix(16))
        let display: String = shortID + "..."
        Text(display)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(AppTheme.silverDim)
    }

    @ViewBuilder
    private var licenseSection: some View {
        Section {
            licenseStatusRow
            if let expiry = licenseManager.expirationDate {
                LabeledContent("Expires") {
                    Text(expiry, style: .date)
                        .foregroundStyle(AppTheme.silverDim)
                }
            }
            Button {
                showDeactivateAlert = true
            } label: {
                Label("Deactivate License", systemImage: "key.slash.fill")
                    .foregroundStyle(AppTheme.warning)
            }
        } header: {
            Text("License").foregroundStyle(AppTheme.accentBright)
        } footer: {
            Text("Deactivate will remove the activation from this device. You can re-activate with the same key on another device.")
                .foregroundStyle(AppTheme.silverDim)
        }
    }

    @ViewBuilder
    private var licenseStatusRow: some View {
        let isActive: Bool = licenseManager.isActive
        HStack {
            Image(systemName: isActive ? "checkmark.seal.fill" : "xmark.seal.fill")
                .foregroundStyle(isActive ? AppTheme.success : AppTheme.danger)
                .frame(width: 24)
            Text(isActive ? "Active" : "Inactive")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.silver)
            Spacer()
        }
    }

    @ViewBuilder
    private var versionSupportSection: some View {
        Section {
            HStack {
                Text(language.text("settings.current_version"))
                Spacer()
                supportStatusText
            }
            LabeledContent("iOS 17", value: ExploitSupportPolicy.verifiedIOS17Range)
            LabeledContent("iOS 18", value: ExploitSupportPolicy.verifiedIOS18Range)
            LabeledContent("iOS 26", value: ExploitSupportPolicy.verifiedIOS26Range)
        } header: {
            Text(language.text("settings.verified_versions")).foregroundStyle(AppTheme.accentBright)
        }
    }

    @ViewBuilder
    private var supportStatusText: some View {
        let isSupported: Bool = appState.isSupported
        let key: String = isSupported ? "settings.supported" : "settings.unsupported"
        Text(language.text(key))
            .fontWeight(.bold)
            .foregroundStyle(isSupported ? AppTheme.success : AppTheme.danger)
    }

    @ViewBuilder
    private var dangerZoneSection: some View {
        Section {
            Button {
                showResetAlert = true
            } label: {
                Label("Reset All Patches", systemImage: "trash.fill")
                    .foregroundStyle(AppTheme.danger)
            }
            Button {
                showRestartAlert = true
            } label: {
                Label("Reset All Data (Clean Install)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.danger)
            }
        } header: {
            Text("Danger Zone").foregroundStyle(AppTheme.danger)
        } footer: {
            Text("Reset All Patches will remove all patch backups and reset patch states.\nReset All Data will remove everything including license.")
                .foregroundStyle(AppTheme.silverDim)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }

    private func performResetPatches() {
        do {
            try DevicePatchService.resetAllPatches()
            UserDefaults.standard.removeObject(forKey: "aimDragEnabled")
            UserDefaults.standard.removeObject(forKey: "aimNeckEnabled")
            UserDefaults.standard.removeObject(forKey: "hspeitoffEnabled")
            UserDefaults.standard.removeObject(forKey: "aimBodyPackageEnabled")
            UserDefaults.standard.removeObject(forKey: "aimChestPackageEnabled")
            UserDefaults.standard.removeObject(forKey: "magicEnabled")
            resetMessage = "All patches reset successfully!"
            showResultAlert = true
        } catch {
            resetMessage = "Reset failed: \(error.localizedDescription)"
            showResultAlert = true
        }
    }

    private func performResetAllData() {
        do {
            try DevicePatchService.resetAllPatches()
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
            UserDefaults.standard.synchronize()
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            try? FileManager.default.removeItem(at: documentsURL)
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            try? FileManager.default.removeItem(at: appSupportURL)
            resetMessage = "All data reset successfully! Please restart the app."
            showResultAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exit(0) }
        } catch {
            resetMessage = "Reset failed: \(error.localizedDescription)"
            showResultAlert = true
        }
    }
}
