import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseManager: LicenseManager
    @EnvironmentObject private var remoteConfig: RemoteConfigService
    @AppStorage("selected_target") private var selectedTarget = "freefireth"
    @AppStorage(AccentStore.storageKey) private var accentRaw = AccentPreset.cyan.rawValue

    @State private var showResetAlert = false
    @State private var resetMessage = ""
    @State private var showRestartAlert = false
    @State private var showResultAlert = false
    @State private var showDeactivateAlert = false
    @State private var showGuestResetAlert = false
    @State private var isResettingGuest = false
    @State private var expandedVersion: String?

    private var accent: Color {
        (AccentPreset(rawValue: accentRaw) ?? .cyan).color
    }

    // ═══ REMOTE CONFIG: dynamic support links ═══
    private var supportWhatsApp: String {
        remoteConfig.supportWhatsApp ?? licenseManager.supportWhatsApp
    }

    private var supportTelegram: String {
        remoteConfig.supportTelegram ?? licenseManager.supportTelegram
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BP.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 10) {
                        deviceSection          // includes Support + License
                        targetSection
                        accentSection
                        versionSection
                        guestSection
                        dangerSection
                    }
                    .padding(12)
                }
            }
            .navigationTitle("SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("DONE") { dismiss() }
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(accent)
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
                Text("Are you sure you want to remove the activation from this device?")
            }
            .alert("Reset Guest FF", isPresented: $showGuestResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) { performGuestReset() }
            } message: {
                Text("This will write a reset flag to FF's LocalConfig.json.\n\nFF will create a fresh guest account next time you open it.\n\n⚠️ Make sure FF is CLOSED first.")
            }
            .alert("Result", isPresented: $showResultAlert) {
                Button("OK") { resetMessage = "" }
            } message: {
                Text(resetMessage)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 01 DEVICE (device info + support + license)

    private var deviceSection: some View {
        BPSection(index: 1, title: "Device", accentColor: accent) {
            VStack(alignment: .leading, spacing: 10) {
                deviceRow("Hardware", AppInfo.displayMachineName)
                deviceRow("iOS", "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                deviceRow("Device ID", String(licenseManager.deviceID.prefix(16)) + "...")
                deviceRow("Target", selectedTarget == "freefiremax" ? "FF Max" : "FF Normal")

                Rectangle().fill(BP.line).frame(height: 0.5).padding(.vertical, 4)

                // Support
                HStack(spacing: 8) {
                    Image(systemName: appState.isSupported ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .foregroundStyle(appState.isSupported ? BP.success : BP.danger)
                        .font(.system(size: 14))
                    Text("SUPPORT")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(BP.textFaint)
                    Spacer()
                    Text(appState.isSupported ? "SUPPORTED" : "UNSUPPORTED")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(appState.isSupported ? BP.success : BP.danger)
                }

                // License
                HStack(spacing: 8) {
                    Image(systemName: licenseManager.isActive ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .foregroundStyle(licenseManager.isActive ? BP.success : BP.danger)
                        .font(.system(size: 14))
                    Text("LICENSE")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(BP.textFaint)
                    Spacer()
                    if let expiry = licenseManager.expirationDate {
                        Text(expiry, style: .date)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(BP.textFaint)
                    }
                    Text(licenseManager.isActive ? "ACTIVE" : "INACTIVE")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(licenseManager.isActive ? BP.success : BP.danger)
                }

                Button {
                    showDeactivateAlert = true
                } label: {
                    Text("DEACTIVATE LICENSE")
                }
                .buttonStyle(BPButtonStyle(color: BP.warning))
                .padding(.top, 4)
            }
        }
    }

    private func deviceRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(BP.textFaint)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(BP.text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - 02 TARGET GAME

    private var targetSection: some View {
        BPSection(index: 2, title: "Target Game", accentColor: accent) {
            HStack(spacing: 8) {
                targetButton("FF NORMAL", value: "freefireth")
                targetButton("FF MAX", value: "freefiremax")
            }
        }
    }

    private func targetButton(_ label: String, value: String) -> some View {
        Button {
            selectedTarget = value
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(selectedTarget == value ? BP.bg : BP.textDim)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(selectedTarget == value ? accent : BP.panelHi)
                .overlay(Rectangle().stroke(selectedTarget == value ? accent : BP.lineBright, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 03 ACCENT COLOR

    private var accentSection: some View {
        BPSection(index: 3, title: "Accent Color", accentColor: accent) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                ForEach(AccentPreset.allCases) { preset in
                    Button {
                        accentRaw = preset.rawValue
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(preset.color)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle().stroke(Color.white.opacity(accentRaw == preset.rawValue ? 1 : 0), lineWidth: 2)
                                )
                            Text(preset.displayName.uppercased())
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .tracking(1.0)
                                .foregroundStyle(accentRaw == preset.rawValue ? preset.color : BP.textFaint)
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(BP.panelHi)
                        .overlay(Rectangle().stroke(
                            accentRaw == preset.rawValue ? preset.color : BP.lineBright,
                            lineWidth: accentRaw == preset.rawValue ? 1.2 : 0.5
                        ))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 04 VERSION SUPPORT

    private var versionSection: some View {
        BPSection(index: 4, title: "Version Support", accentColor: accent) {
            VStack(spacing: 0) {
                let current = currentIOSMajor()
                versionRow(
                    major: current,
                    range: rangeFor(major: current),
                    isCurrent: true
                )
                ForEach(otherVersions(current: current), id: \.self) { major in
                    versionRow(
                        major: major,
                        range: rangeFor(major: major),
                        isCurrent: false
                    )
                }
            }
        }
    }

    private func versionRow(major: Int, range: String, isCurrent: Bool) -> some View {
        let isExpanded = expandedVersion == "iOS \(major)" || isCurrent
        let otherVersionsList = otherVersions(current: currentIOSMajor())

        return VStack(spacing: 0) {
            Button {
                if !isCurrent {
                    withAnimation(.easeOut(duration: 0.2)) {
                        expandedVersion = (expandedVersion == "iOS \(major)") ? nil : "iOS \(major)"
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isCurrent {
                        Circle().fill(accent).frame(width: 6, height: 6)
                    } else {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(BP.textFaint)
                            .frame(width: 6)
                    }
                    Text("iOS \(major)")
                        .font(.system(size: 11, weight: isCurrent ? .heavy : .medium, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(isCurrent ? accent : BP.textDim)
                    Spacer()
                    Text(range)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(BP.textFaint)
                    if isCurrent {
                        BPBadge(text: "YOU", color: accent)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isCurrent && isExpanded {
                Text("Supported build range: \(range)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(BP.textFaint)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if major != otherVersionsList.last {
                Rectangle().fill(BP.line).frame(height: 0.5)
            }
        }
    }

    private func currentIOSMajor() -> Int {
        AppInfo.versionTuple.major
    }

    private func rangeFor(major: Int) -> String {
        switch major {
        case 17: return ExploitSupportPolicy.verifiedIOS17Range
        case 18: return ExploitSupportPolicy.verifiedIOS18Range
        case 26: return ExploitSupportPolicy.verifiedIOS26Range
        default: return "Unsupported"
        }
    }

    private func otherVersions(current: Int) -> [Int] {
        [17, 18, 26].filter { $0 != current }
    }

    // MARK: - 05 GUEST RESET

    private var guestSection: some View {
        BPSection(index: 5, title: "Guest Reset", accentColor: accent) {
            let ff = FFGuestReset.isFFInstalled()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: ff.normal || ff.max ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(ff.normal || ff.max ? BP.success : BP.textFaint)
                    Text(ff.normal || ff.max ? "FF INSTALLED" : "FF NOT INSTALLED")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(BP.textDim)
                    Spacer()
                    if ff.normal { BPBadge(text: "NORMAL", color: accent) }
                    if ff.max { BPBadge(text: "MAX", color: BP.warning) }
                }

                // Info box
                if ff.normal || ff.max {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(BP.info)
                        Text("Writes reset flag to LocalConfig.json.\nFF will create fresh guest on next launch.")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(BP.textDim)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BP.info.opacity(0.08))
                    .overlay(
                        Rectangle().stroke(BP.info.opacity(0.3), lineWidth: 0.5)
                    )
                }

                Button {
                    showGuestResetAlert = true
                } label: {
                    HStack(spacing: 6) {
                        if isResettingGuest { ProgressView().scaleEffect(0.7) }
                        Text(isResettingGuest ? "RESETTING..." : "RESET GUEST FF")
                    }
                }
                .buttonStyle(BPButtonStyle(color: BP.danger))
                .disabled((!ff.normal && !ff.max) || isResettingGuest)
            }
        }
    }

    // MARK: - 06 DANGER ZONE

    private var dangerSection: some View {
        BPSection(index: 6, title: "Danger Zone", accentColor: BP.danger) {
            VStack(spacing: 8) {
                Button { showResetAlert = true } label: {
                    Text("RESET ALL PATCHES")
                }
                .buttonStyle(BPButtonStyle(color: BP.danger))

                Button { showRestartAlert = true } label: {
                    Text("RESET ALL DATA")
                }
                .buttonStyle(BPButtonStyle(color: BP.danger, filled: true))
            }
        }
    }

    // MARK: - Actions

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

    private func performGuestReset() {
        isResettingGuest = true

        log("SettingsView: performing guest reset...")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let report = try FFGuestReset.resetAllGuests()

                DispatchQueue.main.async {
                    isResettingGuest = false

                    if report.perBundle.isEmpty && report.errors.isEmpty {
                        resetMessage = """
                        No FF installed on this device.

                        Install Free Fire first, then try again.
                        """
                    } else {
                        resetMessage = """
                        ✅ Reset Guest FF Success

                        \(report.summary)

                        ⚠️ Next Steps:
                        1. Close External Nixx
                        2. Open Free Fire
                        3. FF will create a new guest automatically
                        4. Login with your FF account
                        """
                    }
                    showResultAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    isResettingGuest = false
                    resetMessage = """
                    ❌ Reset Failed

                    \(error.localizedDescription)

                    Make sure:
                    • FF is CLOSED
                    • Kernel exploit is active
                    • FF is installed
                    """
                    showResultAlert = true
                }
            }
        }
    }
}
