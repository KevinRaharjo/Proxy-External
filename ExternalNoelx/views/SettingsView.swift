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
                Section {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("External Nixx").font(.headline)
                            Text(language.text("common.version", appVersion))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Picker("Target Game", selection: $selectedTarget) {
                        Text("FF Normal").tag("freefireth")
                        Text("FF Max").tag("freefiremax")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Target Game")
                } footer: {
                    Text("Pilih game yang mau di-patch. Patch akan di-load sesuai target.")
                }

                Section(language.text("settings.language")) {
                    Picker(language.text("settings.language"), selection: $languageCode) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section(language.text("common.device")) {
                    LabeledContent(language.text("dashboard.hardware_model"), value: AppInfo.displayMachineName)
                    LabeledContent(language.text("settings.ios_version"), value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                    LabeledContent("Device ID") {
                        Text(String(licenseManager.deviceID.prefix(16)) + "…")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Section("License") {
                    HStack {
                        Image(systemName: licenseManager.isActive ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundStyle(licenseManager.isActive ? .green : .red)
                            .frame(width: 24)
                        Text(licenseManager.isActive ? "Aktif" : "Tidak Aktif")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }

                    if let expiry = licenseManager.expirationDate {
                        LabeledContent("Kadaluarsa") {
                            Text(expiry, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        showDeactivateAlert = true
                    } label: {
                        Label("Deactivate License", systemImage: "key.slash.fill")
                            .foregroundColor(.orange)
                    }
                } header: {
                    Text("License")
                } footer: {
                    Text("Deactivate akan menghapus aktivasi dari device ini. Kamu bisa aktifkan ulang dengan key yang sama di device lain.")
                }

                Section {
                    HStack {
                        Text(language.text("settings.current_version"))
                        Spacer()
                        Text(language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"))
                        .foregroundStyle(appState.isSupported ? Color.green : Color.red)
                    }
                    LabeledContent("iOS 17", value: ExploitSupportPolicy.verifiedIOS17Range)
                    LabeledContent("iOS 18", value: ExploitSupportPolicy.verifiedIOS18Range)
                    LabeledContent("iOS 26", value: ExploitSupportPolicy.verifiedIOS26Range)
                } header: {
                    Text(language.text("settings.verified_versions"))
                }

                Section {
                    Button {
                        showResetAlert = true
                    } label: {
                        Label("Reset All Patches", systemImage: "trash.fill")
                            .foregroundColor(.red)
                    }

                    Button {
                        showRestartAlert = true
                    } label: {
                        Label("Reset All Data (Clean Install)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("⚠️ Danger Zone")
                } footer: {
                    Text("Reset All Patches will remove all patch backups and reset patch states.\nReset All Data will remove everything including license.")
                }
            }
            .tint(AppTheme.accent)
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground)
            .navigationTitle(language.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("common.done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Reset Patches", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    performResetPatches()
                }
            } message: {
                Text("This will remove all patch backups and reset patch states. Are you sure?")
            }
            .alert("Reset All Data", isPresented: $showRestartAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    performResetAllData()
                }
            } message: {
                Text("This will remove everything including license, patches, and all data. Are you sure?")
            }
            .alert("Deactivate License", isPresented: $showDeactivateAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Deactivate", role: .destructive) {
                    licenseManager.deactivate()
                }
            } message: {
                Text("Yakin mau hapus aktivasi dari device ini? Kamu bisa aktifkan ulang dengan key yang sama di device lain.")
            }
            .alert("Result", isPresented: $showResultAlert) {
                Button("OK") {
                    resetMessage = ""
                }
            } message: {
                Text(resetMessage)
            }
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

            resetMessage = "✅ All patches reset successfully!"
            showResultAlert = true
        } catch {
            resetMessage = "❌ Reset failed: \(error.localizedDescription)"
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

            resetMessage = "✅ All data reset successfully! Please restart the app."
            showResultAlert = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                exit(0)
            }
        } catch {
            resetMessage = "❌ Reset failed: \(error.localizedDescription)"
            showResultAlert = true
        }
    }
}
