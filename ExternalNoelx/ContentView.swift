import SwiftUI
import UIKit
import AVFoundation

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseManager: LicenseManager
    @EnvironmentObject private var remoteConfig: RemoteConfigService
    @State private var showSettings = false
    @State private var showCleaner = false
    @State private var showInfo = false
    @StateObject private var patchStore = PatchProjectStore()
    @State private var patchOperationBusy = false
    @State private var patchMessage = "READY — SELECT A PATCH"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var refreshToken = UUID()
    @State private var flagsToken = UUID()
    @State private var selectedCategory: PatchCategory = .aim
    @State private var lastSyncedLicense: String = ""

    @AppStorage("selected_target") private var selectedTarget = "freefireth"

    private var targetFolder: String {
        selectedTarget == "freefiremax" ? "FF Max" : "FF Normal"
    }

    private var filteredPatches: [PatchLibraryItem] {
        patchStore.items.filter { $0.category == selectedCategory }
    }

    private var availableCategories: [PatchCategory] {
        PatchCategory.allCases.filter { category in
            patchStore.items.contains(where: { $0.category == category })
        }
    }

    var body: some View {
        ZStack {
            AnimatedHyperBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // ═══ REMOTE CONFIG: MAINTENANCE BANNER ═══
                    if let banner = remoteConfig.maintenanceBanner {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.warning)
                            Text(banner)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.silver)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.warning.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.warning.opacity(0.4), lineWidth: 1)
                        )
                    }

                    // ═══ REMOTE CONFIG: WELCOME MESSAGE ═══
                    if let welcome = remoteConfig.welcomeMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.accentBright)
                            Text(welcome)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.silver)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.accent.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
                        )
                    }

                    brandHeader
                    categorySelector
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
        .sheet(isPresented: $showInfo) {
            InfoTabView()
        }
        .sheet(item: $patchStore.passwordRequest, onDismiss: patchStore.cancelUnlock) { _ in
            PatchUnlockPrompt(store: patchStore)
        }
        .onAppear {
            patchStore.setTarget(targetFolder)
            patchMessage = "READY — SELECT A PATCH"
            refreshPatchFlags(target: targetFolder)
            ensureValidCategory()
            syncPatchesFromServer()
            fetchSupportedVersions()
        }
        .onChange(of: licenseManager.state) { state in
            if case .active = state {
                syncPatchesFromServer()
                fetchSupportedVersions()
            }
        }
        .onChange(of: selectedTarget) { newTarget in
            let folder = newTarget == "freefiremax" ? "FF Max" : "FF Normal"
            patchStore.setTarget(folder)
            patchMessage = "READY — SELECT A PATCH"
            refreshPatchFlags(target: folder)
            ensureValidCategory()
            syncPatchesFromServer()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active, !patchOperationBusy else { return }
            patchStore.reload()
            patchMessage = "READY — SELECT A PATCH"
            refreshPatchFlags(target: targetFolder)
            ensureValidCategory()
        }
        .onChange(of: patchStore.items.count) { _ in
            ensureValidCategory()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Patch Status"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Server-side sync

    private func syncPatchesFromServer() {
        guard licenseManager.isActive else {
            log("patch-sync: license not active, skipping")
            return
        }
        guard remoteConfig.isPatchSyncEnabled else {
            log("patch-sync: disabled via remote config")
            return
        }
        guard let licenseKey = licenseManager.rememberedKey(), !licenseKey.isEmpty else {
            log("patch-sync: no remembered key, skipping")
            return
        }
        guard licenseKey != lastSyncedLicense else {
            log("patch-sync: already synced for this license")
            return
        }

        let deviceID = licenseManager.deviceID
        lastSyncedLicense = licenseKey

        Task {
            patchMessage = "SYNCING PATCHES…"
            await patchStore.syncFromServer(deviceID: deviceID, license: licenseKey)
            patchMessage = "READY — SELECT A PATCH"
            ensureValidCategory()
        }
    }

    private func fetchSupportedVersions() {
        Task {
            do {
                let versions = try await SupportedVersionsService.shared.fetch(force: false)
                log("supported-versions: fetched \(versions.count) entries")
                for v in versions {
                    log("supported-versions: \(v.range) → \(v.status)")
                }
            } catch {
                log("supported-versions: fetch failed — using fallback (\(error.localizedDescription))")
            }
        }
    }

    private func ensureValidCategory() {
        let available = availableCategories
        guard !available.isEmpty else { return }
        if !available.contains(selectedCategory) {
            withAnimation(.easeInOut(duration: 0.22)) {
                selectedCategory = available[0]
            }
        }
    }

    // MARK: - Patch Flag Integration

    private func refreshPatchFlags(target: String) {
        Task {
            _ = try? await PatchFlagService.shared.fetchFlags(force: true)
            _ = try? await PatchFlagService.shared.fetchKnownPatches(force: true)

            let reportItems = patchStore.items.map {
                PatchReportItem(name: $0.displayName, target: target)
            }
            if !reportItems.isEmpty {
                _ = try? await PatchFlagService.shared.report(
                    reportItems,
                    deviceID: licenseManager.deviceID
                )
            }

            await MainActor.run {
                flagsToken = UUID()
            }
        }
    }

    private func currentFlag(for item: PatchLibraryItem) -> PatchFlag? {
        PatchFlagService.shared.snapshot.get("\(item.displayName)@\(targetFolder)")
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
                Text("EXTERNAL NIXX")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .tracking(2.0)
                    .foregroundStyle(AppTheme.silverGradient)
                    .shadow(color: AppTheme.accentGlow, radius: 6)
                Text(selectedTarget == "freefiremax" ? "FF MAX EDITION" : "FF NORMAL EDITION")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(AppTheme.accentBright)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.accentBright)
                        .frame(width: 46, height: 46)
                        .background(
                            Circle().fill(AppTheme.surfaceElevated)
                        )
                        .overlay(
                            Circle().stroke(AppTheme.borderHighlight, lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Announcements")

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
        }
        .padding(.vertical, 4)
    }

    // MARK: - Category selector

    @ViewBuilder
    private var categorySelector: some View {
        let available = availableCategories

        if available.isEmpty {
            EmptyView()
        } else if available.count == 1 {
            singleCategoryLabel(available[0])
        } else {
            HStack(spacing: 0) {
                ForEach(available) { category in
                    categoryPill(category)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.borderSubtle, lineWidth: 0.8)
                    )
            )
        }
    }

    private func singleCategoryLabel(_ category: PatchCategory) -> some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(category.tint)
            Text(category.displayName)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(AppTheme.silver)
            Spacer()
            Text("\(filteredPatches.count) AVAILABLE")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(AppTheme.silverMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.borderSubtle, lineWidth: 0.8)
                )
        )
    }

    @ViewBuilder
    private func categoryPill(_ category: PatchCategory) -> some View {
        let isSelected = selectedCategory == category

        Button {
            guard !isSelected else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                selectedCategory = category
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .bold))
                Text(category.displayName)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.2)
            }
            .foregroundStyle(isSelected
                             ? AppTheme.silverBright
                             : AppTheme.silverDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.clear)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        category.tint.opacity(0.95),
                                        category.tint.opacity(0.62)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.accentBright.opacity(0.55), lineWidth: 0.8)
                            )
                            .shadow(color: category.tint.opacity(0.45), radius: 10, y: 3)
                            .matchedGeometryEffect(id: "categoryPill", in: categoryNamespace)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @Namespace private var categoryNamespace

    // MARK: - Patch options

    private var patchOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if availableCategories.isEmpty {
                    panelTitle("PATCHES", icon: "shippingbox")
                } else {
                    panelTitle("\(selectedCategory.displayName) PATCHES", icon: selectedCategory.icon)
                }
                Spacer()
                Text("\(filteredPatches.count) AVAILABLE")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(AppTheme.silverMuted)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 4)

            Group {
                if filteredPatches.isEmpty {
                    emptyPatchState
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(filteredPatches) { item in
                            patchCard(item: item)
                        }
                    }
                    .id(refreshToken)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: selectedCategory)

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
            Text("Add AIM-*.3105, ESP-*.3105, or MISC-*.3105\nfiles to Patches/\(targetFolder)/")
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
            tint: selectedCategory.tint,
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

                if remoteConfig.isCleanerEnabled {
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
            Text("EXTERNAL NIXX • ONLINE")
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
            Text("EXTERNAL NIXX Telegram")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.accentBright.opacity(0.85))
            Button {
                let urlStr = remoteConfig.supportTelegram ?? "https://t.me/nixxtime"
                guard let url = URL(string: urlStr) else { return }
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
            alertMessage = note ?? "This patch was flagged by admin: \(label). Cannot be enabled."
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
// MARK: - Patch Tile
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
                    Text("Enter the password once to unlock this EXTERNAL NIXX package on this device.")
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
