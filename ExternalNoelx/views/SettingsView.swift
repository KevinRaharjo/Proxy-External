import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    
    // MARK: - Reset States
    @State private var showResetAlert = false
    @State private var resetMessage = ""
    @State private var showRestartAlert = false
    @State private var showResultAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("External Noelx").font(.headline)
                            Text(language.text("common.version", appVersion))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("iOS 27.0")
                            .font(.body)
                        ForEach(ExploitSupportPolicy.verifiedIOS27Builds, id: \.build) { version in
                            Text(versionLabel(version))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text(language.text("settings.verified_versions"))
                } footer: {
                    Text(language.text("settings.supported_versions_footer"))
                }

                // MARK: - ⚠️ DANGER ZONE - Reset Actions
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
            // MARK: - Alerts
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

    private func versionLabel(
        _ version: (beta: Int, publicBeta: Int?, build: String)
    ) -> String {
        if let publicBeta = version.publicBeta {
            return language.text(
                "settings.developer_public_beta_build",
                Int64(version.beta),
                Int64(publicBeta),
                version.build
            )
        }
        return language.text(
            "settings.developer_beta_build",
            Int64(version.beta),
            version.build
        )
    }

    @ViewBuilder
    private func creditsRow(name: String, role: String, url: String) -> some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(role)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 28, height: 28)
                }
                .contentShape(Rectangle())
            }
            .accessibilityLabel(language.text("accessibility.open_profile", name))
        }
    }
    
    // MARK: - Reset Functions
    
    private func performResetPatches() {
        do {
            try DevicePatchService.resetAllPatches()
            
            // Reset semua state di UserDefaults
            UserDefaults.standard.removeObject(forKey: "aimDragEnabled")
            UserDefaults.standard.removeObject(forKey: "aimNeckEnabled")
            UserDefaults.standard.removeObject(forKey: "hspeitoffEnabled")
            UserDefaults.standard.removeObject(forKey: "hyperBalamagicaEnabled")
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
            // 1. Reset patches
            try DevicePatchService.resetAllPatches()
            
            // 2. Reset license - pake LicenseManager
            if let licenseManager = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first?.rootViewController?
                .view?.window?.windowScene?
                .windows.first?.rootViewController as? UIHostingController<ContentView> {
                // Alternative: use NotificationCenter or shared instance
            }
            
            // 3. Reset semua UserDefaults
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
            UserDefaults.standard.synchronize()
            
            // 4. Hapus semua data di Documents
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            try? FileManager.default.removeItem(at: documentsURL)
            
            // 5. Hapus semua data di Application Support
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            try? FileManager.default.removeItem(at: appSupportURL)
            
            resetMessage = "✅ All data reset successfully! Please restart the app."
            showResultAlert = true
            
            // 6. Restart app setelah 2 detik
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                exit(0)
            }
            
        } catch {
            resetMessage = "❌ Reset failed: \(error.localizedDescription)"
            showResultAlert = true
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
