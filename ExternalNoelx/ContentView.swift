import SwiftUI
import UIKit
import AVFoundation

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseManager: LicenseManager
    @State private var showSettings = false
    @State private var showCleaner = false
    @StateObject private var patchStore = PatchProjectStore()
    @State private var patchOperationBusy = false
    @State private var patchMessage = "READY — SELECT A PATCH"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var refreshToken = UUID()
    @State private var flagsToken = UUID()

    @AppStorage("selected_target") private var selectedTarget = "freefireth"

    var body: some View {
        ZStack {
            AnimatedHyperBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    brandHeader
                    devicePanel
                    patchOptions
                    gameLaunchPanel
                    footerStatus
                    developerCredits
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showCleaner) {
            CleanerView()
        }
        .sheet(item: $patchStore.passwordRequest, onDismiss: patchStore.cancelUnlock) { _ in
            PatchUnlockPrompt(store: patchStore)
        }
        .onAppear {
            let targetFolder = selectedTarget == "freefiremax" ? "FF Max" : "FF Normal"
            patchStore.setTarget(targetFolder)
            patchMessage = "READY — SELECT A PATCH"
            refreshPatchFlags(target: targetFolder)
        }
        .onChange(of: selectedTarget) { newTarget in
            let targetFolder = newTarget == "freefiremax" ? "FF Max" : "FF Normal"
            patchStore.setTarget(targetFolder)
            patchMessage = "READY — SELECT A PATCH"
            refreshPatchFlags(target: targetFolder)
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active, !patchOperationBusy else { return }
            patchStore.reload()
            patchMessage = "READY — SELECT A PATCH"
            let targetFolder = selectedTarget == "freefiremax" ? "FF Max" : "FF Normal"
            refreshPatchFlags(target: targetFolder)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Patch Status"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Patch Flag Integration

    private func refreshPatchFlags(target: String) {
        Task {
            // 1. Fetch flag terbaru (untuk badge di card)
            _ = try? await PatchFlagService.shared.fetchFlags(force: true)

            // 2. Fetch daftar patch yang SUDAH ada di server
            _ = try? await PatchFlagService.shared.fetchKnownPatches(force: true)

            // 3. Report — service otomatis filter, hanya kirim yang BELUM ada
            let reportItems = patchStore.items.map {
                PatchReportItem(name: $0.displayName, target: target)
            }
            if !reportItems.isEmpty {
                _ = try? await PatchFlagService.shared.report(
                    reportItems,
                    deviceID: licenseManager.deviceID
                )
            }

            // 4. Trigger re-render supaya badge + note muncul
            await MainActor.run {
                flagsToken = UUID()
            }
        }
    }

    private func currentFlag(for item: PatchLibraryItem) -> PatchFlag? {
        let targetFolder = selectedTarget == "freefiremax" ? "FF Max" : "FF Normal"
        return PatchFlagService.shared.snapshot.get("\(item.displayName)@\(targetFolder)")
    }

    // MARK: - Brand header

    private var brandHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.glowGradient)
                    .frame(width: 56, height: 56)
                AppLogo(size: 46)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("External Nixx")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(AppTheme.silverGradient)
                    .shadow(color: AppTheme.accentGlow, radius: 6)
                Text(selectedTarget == "freefiremax" ? "FF MAX EDITION" : "FF NORMAL EDITION")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(AppTheme.accentBright)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.silver)
                    .frame(width: 46, height: 46)
                    .background(
                        Circle().fill(AppTheme.surfaceElevated)
                    )
                    .overlay(
                        Circle().stroke(AppTheme.borderHighlight, lineWidth: 0.8)
                    )
                    .shadow(color: AppTheme.accentGlow, radius: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open settings")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Device panel

    private var devicePanel: some View {
        AppSurfaceCard(corner: AppTheme.cardCorner, glowColor: AppTheme.accent, glowActive: false) {
            VStack(spacing: 0) {
                panelTitle("DEVICE STATUS", icon: "shield.lefthalf.filled")
                statusRow(icon: "apple.logo", title: "iOS", value: AppInfo.osVersion, color: AppTheme.accentBright)
                statusRow(icon: "iphone", title: "Device", value: AppInfo.displayMachineName, color: AppTheme.silver)
                statusRow(
                    icon: licenseManager.isActive ? "checkmark.seal.fill" : "xmark.seal.fill",
                    title: "License",
                    value: licenseManager.isActive ? "ACTIVE" : "INACTIVE",
                    color: licenseManager.isActive ? AppTheme.success : AppTheme.danger
                )
                statusRow(
                    icon: appState.isSupported ? "checkmark.shield.fill" : "xmark.shield.fill",
                    title: "Support",
                    value: appState.isSupported ? "SUPPORTED" : "UNSUPPORTED",
                    color: appState.isSupported ? AppTheme.success : AppTheme.danger
                )
            }
        }
    }

    // MARK: - Patch options

    private var patchOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                panelTitle("PATCH OPTIONS", icon: "bolt.fill")
                Spacer()
                Text("\(patchStore.items.count) PATCHES")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(AppTheme.silverMuted)
            }
            .padding(.horizontal, 4)

            if patchStore.items.isEmpty {
                emptyPatchState
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(patchStore.items) { item in
                        patchCard(item: item)
                    }
                }
                .id(refreshToken)
            }

            patchStatusBar
        }
    }

    private var emptyPatchState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(AppTheme.silverMuted)
            Text("No patches found")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.silver)
            Text("Add .3105 files to Patches/\(selectedTarget == "freefiremax" ? "FF Max" : "FF Normal")/")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.silverMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.borderSubtle, lineWidth: 0.8)
                )
        )
    }

    private var patchStatusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(patchMessage.localizedCaseInsensitiveContains("✅") ? AppTheme.success : AppTheme.accent)
                .frame(width: 7, height: 7)
                .shadow(
                    color: (patchMessage.localizedCaseInsensitiveContains("✅")
                            ? AppTheme.success
                            : AppTheme.accent).opacity(0.8),
                    radius: 5
                )
            Text(patchOperationBusy ? "PROCESSING PATCH…" : patchMessage)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(AppTheme.silverDim)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            Capsule().fill(AppTheme.surface)
        )
        .overlay(
            Capsule().stroke(AppTheme.borderSubtle, lineWidth: 0.8)
        )
        .padding(.horizontal, 4)
    }

    // MARK: - Patch Card

    private func patchCard(item: PatchLibraryItem) -> some View {
        let isEnabled = DevicePatchService.latestReceipt(projectID: item.id) != nil
        let flag = currentFlag(for: item)

        return PatchTile(
            name: item.displayName,
            target: selectedTarget == "freefiremax" ? "FREE FIRE • MAX" : "FREE FIRE • NORMAL",
            isEnabled: isEnabled,
            isBusy: patchOperationBusy,
            tint: AppTheme.accent,
            flag: flag
        ) { newValue in
            togglePatch(item: item, currentlyEnabled: isEnabled, wantEnable: newValue)
        }
        .id("\(item.id)-\(flagsToken)")
    }

    // MARK: - Launch panel

    private var gameLaunchPanel: some View {
        AppSurfaceCard(corner: AppTheme.cardCorner, glowColor: AppTheme.accent, glowActive: false) {
            VStack(alignment: .leading, spacing: 14) {
                panelTitle("LAUNCH GAME", icon: "arrow.up.forward.app.fill")

                Button {
                    openGame(scheme: selectedTarget == "freefiremax" ? "freefiremax" : "freefireth")
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.accent.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.accentBright)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectedTarget == "freefiremax" ? "FF MAX" : "FF NORMAL")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(AppTheme.silver)
                            Text(selectedTarget == "freefiremax" ? "Free Fire Max" : "Free Fire Normal")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.silverDim)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(AppTheme.accentBright)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.accent.opacity(0.45), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showCleaner = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "trash.slash.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.silver)
                        Text("Clean Cache & Temp")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.silver)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.borderHighlight, lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Footer

    private var footerStatus: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(AppTheme.success)
                .frame(width: 9, height: 9)
                .shadow(color: AppTheme.success, radius: 6)
            Text("SYSTEM READY")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(AppTheme.silverDim)
            Spacer()
            Text("External Nixx • ONLINE")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.accentBright.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Capsule().fill(AppTheme.surface))
        .overlay(Capsule().stroke(AppTheme.borderSubtle, lineWidth: 0.8))
    }

    private var developerCredits: some View {
        VStack(spacing: 10) {
            Text("Developed by Kevin")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.silverDim)
            Text("External Nixx Telegram")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.accentBright.opacity(0.85))
            Button {
                guard let url = URL(string: "https://t.me/nixxtime") else { return }
                UIApplication.shared.open(url)
            } label: {
                Label("Open Channel", systemImage: "paperplane.fill")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.silver)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(AppTheme.accent.opacity(0.18))
                    )
                    .overlay(
                        Capsule().stroke(AppTheme.accent.opacity(0.45), lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    // MARK: - Helpers

    private func panelTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(AppTheme.accentBright)
    }

    private func statusRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.silverDim)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.silver)
        }
        .padding(.top, 14)
    }

    // MARK: - Actions

    private enum PatchActionResult {
        case applied
        case restored
        case unavailable(String)
    }

    private func togglePatch(item: PatchLibraryItem, currentlyEnabled: Bool, wantEnable: Bool) {
        if let flag = currentFlag(for: item) {
            let note = (flag.note?.isEmpty == false) ? flag.note! : nil
            let label = (flag.label?.isEmpty == false) ? flag.label! : "Flagged"
            alertMessage = note ?? "Patch ini ditandai oleh admin: \(label). Tidak bisa diaktifkan."
            showAlert = true
            refreshToken = UUID()
            return
        }

        guard !patchOperationBusy else { return }
        if currentlyEnabled == wantEnable { return }

        patchOperationBusy = true
        patchMessage = wantEnable ? "APPLYING — \(item.displayName)" : "RESTORING — \(item.displayName)"

        let project = item.project
        let projectID = item.id

        DispatchQueue.global(qos: .userInitiated).async {
            let result: PatchActionResult
            do {
                if !wantEnable {
                    guard let receipt = DevicePatchService.latestReceipt(projectID: projectID) else {
                        result = .unavailable("NO ACTIVE RECEIPT — NOTHING TO RESTORE")
                        DispatchQueue.main.async {
                            self.patchMessage = "OFF — NO ACTIVE PATCH FOUND"
                            self.patchOperationBusy = false
                            self.refreshToken = UUID()
                        }
                        return
                    }
                    try DevicePatchService.restore(receipt: receipt)
                    result = .restored
                } else {
                    guard let project else {
                        result = .unavailable("PASSWORD REQUIRED — UNLOCK PACKAGE")
                        DispatchQueue.main.async {
                            self.patchStore.requestUnlock(for: item)
                            self.patchMessage = "PASSWORD REQUIRED — ENTER PACKAGE PASSWORD"
                            self.patchOperationBusy = false
                            self.refreshToken = UUID()
                        }
                        return
                    }
                    _ = try DevicePatchService.apply(project: project)
                    result = .applied
                }
            } catch {
                result = .unavailable("FAILED — \(String(describing: error))")
            }

            DispatchQueue.main.async {
                switch result {
                case .applied:
                    self.patchMessage = "✅ Applied — \(item.displayName)"
                    PatchAudioFeedback.bypassActivated()
                case .restored:
                    self.patchMessage = "✅ Restored — \(item.displayName)"
                    PatchAudioFeedback.originalRestored()
                case .unavailable(let message):
                    self.patchMessage = "❌ \(message)"
                    self.alertMessage = message
                    self.showAlert = true
                }
                self.patchOperationBusy = false
                self.refreshToken = UUID()
            }
        }
    }

    private func openGame(scheme: String) {
        guard let url = URL(string: "\(scheme)://") else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            log("launch: \(scheme) success=\(success)")
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Patch Tile (with NotchSliderToggle + Flag Badge)
// ═══════════════════════════════════════════════════════════════════════

private struct PatchTile: View {
    let name: String
    let target: String
    let isEnabled: Bool
    let isBusy: Bool
    let tint: Color
    let flag: PatchFlag?
    let onChange: (Bool) -> Void

    @State private var toggleState: Bool

    init(
        name: String,
        target: String,
        isEnabled: Bool,
        isBusy: Bool,
        tint: Color,
        flag: PatchFlag? = nil,
        onChange: @escaping (Bool) -> Void
    ) {
        self.name = name
        self.target = target
        self.isEnabled = isEnabled
        self.isBusy = isBusy
        self.tint = tint
        self.flag = flag
        self.onChange = onChange
        _toggleState = State(initialValue: isEnabled)
    }

    private var isFlagged: Bool { flag != nil }
    private var flagTint: Color { AppTheme.warning }

    private var borderColor: Color {
        if isFlagged { return flagTint.opacity(0.9) }
        if isEnabled { return tint.opacity(0.85) }
        return AppTheme.borderSubtle
    }

    private var borderWidth: CGFloat {
        if isFlagged { return 1.5 }
        if isEnabled { return 1.3 }
        return 0.8
    }

    private var statusText: String {
        if isFlagged { return "BLOCKED BY ADMIN" }
        return isEnabled ? "PATCH ACTIVE" : "TAP TO ACTIVATE"
    }

    private var headerIcon: String {
        if isFlagged { return "exclamationmark.triangle.fill" }
        return isEnabled ? "bolt.fill" : "bolt.slash.fill"
    }

    private var headerIconColor: Color {
        if isFlagged { return flagTint }
        return isEnabled ? tint : AppTheme.silverMuted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: headerIcon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(headerIconColor)
                Spacer()
                NotchSliderToggle(
                    isOn: $toggleState,
                    tint: isFlagged ? flagTint : tint,
                    isBusy: isBusy || isFlagged
                ) { newValue in
                    onChange(newValue)
                }
            }

            Rectangle()
                .fill(AppTheme.borderSubtle)
                .frame(height: 0.6)
                .opacity(0.7)

            Text(name)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.silver)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(target)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(isFlagged ? flagTint : (isEnabled ? tint : AppTheme.silverMuted))

            if isFlagged {
                flagBadge
                if let note = flag?.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.silverDim)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(isFlagged
                          ? flagTint
                          : (isEnabled ? AppTheme.success : AppTheme.silverMuted))
                    .frame(width: 6, height: 6)
                Text(statusText)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.silverDim)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 158, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .shadow(
            color: isFlagged
                ? flagTint.opacity(0.30)
                : (isEnabled ? tint.opacity(0.25) : Color.black.opacity(0.35)),
            radius: isFlagged ? 14 : (isEnabled ? 14 : 8),
            y: 4
        )
        .glowPulse(active: isEnabled && !isFlagged, color: tint)
        .opacity(isBusy ? 0.6 : 1)
        .onChange(of: isEnabled) { newValue in
            toggleState = newValue
        }
    }

    @ViewBuilder
    private var flagBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(flagTint)
            Text((flag?.label ?? "FLAGGED").uppercased())
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(flagTint)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(flagTint.opacity(0.15))
        )
        .overlay(
            Capsule().stroke(flagTint.opacity(0.5), lineWidth: 0.7)
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Audio feedback
// ═══════════════════════════════════════════════════════════════════════

private enum PatchAudioFeedback {
    private static let synthesizer = AVSpeechSynthesizer()

    static func bypassActivated() { speak("Bypass activated") }
    static func originalRestored() { speak("Bypass deactivated") }

    private static func speak(_ message: String) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: [])
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: message)
        let voices = AVSpeechSynthesisVoice.speechVoices()
        utterance.voice = voices.first(where: {
            ($0.language.hasPrefix("en-US") || $0.language.hasPrefix("en-GB") || $0.language.hasPrefix("en")) && $0.quality == .enhanced
        }) ?? voices.first(where: {
            $0.language.hasPrefix("en-US") || $0.language.hasPrefix("en-GB") || $0.language.hasPrefix("en")
        }) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.46
        utterance.pitchMultiplier = 1.05
        utterance.volume = 0.85
        synthesizer.speak(utterance)
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Unlock prompt
// ═══════════════════════════════════════════════════════════════════════

private struct PatchUnlockPrompt: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Package password", text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)
                        .onSubmit(unlock)
                        .onChange(of: password) { _ in store.clearUnlockError() }
                    if let errorKey = store.unlockErrorKey {
                        Text(AppLanguage.english.text(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Enter the password once to unlock this External Nixx package on this device.")
                }
            }
            .navigationTitle("Unlock package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Unlock", action: unlock)
                        .disabled(password.isEmpty || store.isBusy)
                }
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}
