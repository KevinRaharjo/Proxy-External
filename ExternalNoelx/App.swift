import SwiftUI
import UIKit

@main
struct ExternalNoelxApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var licenseManager = LicenseManager()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @StateObject private var remoteConfig = RemoteConfigService.shared
    @AppStorage("selected_target") private var selectedTarget = ""
    @State private var updateOffer: AppUpdateChecker.Offer?
    @Environment(\.scenePhase) private var scenePhase

    private let language: AppLanguage = .english

    init() {
        setupLogCapture()
        log("app: External Nixx launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")

        do {
            _ = try PatchProjectLibrary.ensurePatchesDirectory()
            log("app: patches directory ready")
        } catch {
            log("app: failed to ensure patches directory: \(error.localizedDescription)")
        }
        PatchProjectLibrary.installBundledPackagesIfNeeded()
    }

    private func checkForUpdate() {
        Task {
            guard let offer = await AppUpdateChecker.check() else { return }
            await MainActor.run { updateOffer = offer }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if remoteConfig.isForceUpdateRequired {
                    ForceUpdateView(
                        message: "A new version is required. Please update to continue.",
                        updateURL: remoteConfig.forceUpdateUrl
                    )
                } else {
                    switch licenseManager.state {
                    case .checking:
                        ZStack {
                            AnimatedHyperBackdrop()
                                .ignoresSafeArea()
                            VStack(spacing: 20) {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.3)
                                Text("Verifying license…")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }

                    case .maintenance:
                        MaintenanceView(manager: licenseManager)

                    case .inactive:
                        LicenseActivationView(manager: licenseManager)

                    case .active:
                        if selectedTarget.isEmpty {
                            TargetSelectionView(selectedTarget: $selectedTarget)
                        } else {
                            ContentView()
                                .environmentObject(licenseManager)
                        }

                    case .offline:
                        LicenseActivationView(manager: licenseManager)
                    }
                }
            }
            .environmentObject(appState)
            .environmentObject(patchDraftCoordinator)
            .environmentObject(fileOperationCoordinator)
            .environmentObject(remoteConfig)
            .environment(\.appLanguage, language)
            .environment(\.locale, language.locale)
            .alert(item: $updateOffer) { offer in
                Alert(
                    title: Text(language.text("update.title")),
                    message: Text(language.text("update.message", offer.version)),
                    primaryButton: .default(Text(language.text("update.agree"))) {
                        UIApplication.shared.open(offer.url)
                    },
                    secondaryButton: .cancel(Text(language.text("update.dismiss"))) {
                        AppUpdateChecker.dismiss(version: offer.version)
                    }
                )
            }
            .onAppear {
                licenseManager.beginLaunchSession()
                appState.detectSupport()
                checkForUpdate()
            }
            .task {
                await remoteConfig.fetch()
                log("remote-config: min=\(remoteConfig.minAppVersion), forceUpdate=\(remoteConfig.isForceUpdateRequired)")
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }

                if licenseManager.shouldReverifyOnForeground() {
                    licenseManager.beginLaunchSession()
                }

                appState.detectSupport()

                Task {
                    await remoteConfig.fetch()
                }
            }
            .onOpenURL { url in
                patchDraftCoordinator.presentImport(url)
            }
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - AppState

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        let applicable = KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        guard applicable else { return }

        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed,
              !autoRunAttempted else { return }
        autoRunAttempted = true
        log("app: starting kernel exploit automatically")
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess {
                    exploitStatus = .success(method: "kexploit")
                    log("app: existing sandbox access is still active; skipping kernel exploit")
                }
            } else if exploitStatus.isSuccess {
                exploitStatus = .notStarted
                log("app: sandbox access is no longer active")
            }
        }
    }

    func runKernelExploitIfNeeded() {
        refreshKernelExploitStatus()
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed else { return }
        kernelExploitRunning = true
        exploitStatus = .notStarted

        let major = AppInfo.versionTuple.major
        let method = major >= 26 ? "BadKernel" : "kexploit"
        log("app: running \(method) on background...")

        DispatchQueue.global(qos: .userInitiated).async {
            let ok = ExploitRouter.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                if ok {
                    self.exploitStatus = .success(method: method)
                    log("app: \(method) success — access active")
                } else {
                    self.exploitStatus = .failed(method: method, code: -1)
                    log("app: \(method) failed — relaunch before retrying")
                }
            }
        }
    }
}
