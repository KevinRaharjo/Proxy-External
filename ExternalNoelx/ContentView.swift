//
//  ContentView.swift
//  ExternalNoelx
//
//  Created by User on 22/03/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showLogView = false
    
    // MARK: - Patch States
    @AppStorage("aimDragEnabled") private var aimDragEnabled = false
    @AppStorage("aimNeckEnabled") private var aimNeckEnabled = false
    @AppStorage("hspeitoffEnabled") private var hspeitoffEnabled = false
    @AppStorage("hyperBalamagicaEnabled") private var hyperBalamagicaEnabled = false
    @AppStorage("aimBodyPackageEnabled") private var aimBodyPackageEnabled = false
    @AppStorage("aimChestPackageEnabled") private var aimChestPackageEnabled = false
    @AppStorage("magicEnabled") private var magicEnabled = false
    
    @State private var isApplying = false
    @State private var applyMessage: String?
    @State private var showAlert = false
    
    @StateObject private var licenseManager = LicenseManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Content based on tab
                    if selectedTab == 0 {
                        patchesView
                    } else if selectedTab == 1 {
                        FilesTabSwitcherView()
                    } else if selectedTab == 2 {
                        CleanerView()
                    } else if selectedTab == 3 {
                        SettingsView()
                    } else if selectedTab == 4 {
                        WallpaperLabView()
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Bottom Tab Bar
                    tabBarView
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Apply Patches"),
                    message: Text(applyMessage ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                loadPatchStates()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("OGIOS")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.1")")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Spacer()
            
            // License Status
            if licenseManager.isLicensed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Licensed")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .cornerRadius(8)
            }
            
            Button(action: { showLogView.toggle() }) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            .sheet(isPresented: $showLogView) {
                LogView()
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(AppTheme.surface)
    }
    
    // MARK: - Patches View
    private var patchesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Info Banner
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(AppTheme.accent)
                    Text("Toggle patches below to apply modifications")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText)
                    Spacer()
                }
                .padding()
                .background(AppTheme.surface)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Patches Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    patchCard(
                        name: "Aim Drag",
                        target: "FREE FIRE • NORMAL",
                        package: "Noelx File (6).3105",
                        color: AppTheme.accent,
                        state: $aimDragEnabled
                    )
                    
                    patchCard(
                        name: "Aim Neck",
                        target: "FREE FIRE • NORMAL",
                        package: "Noelx File (7).3105",
                        color: AppTheme.secondaryAccent,
                        state: $aimNeckEnabled
                    )
                    
                    patchCard(
                        name: "Antenna",
                        target: "FREE FIRE • NORMAL",
                        package: "Noelx File (8).3105",
                        color: AppTheme.secondaryAccent,
                        state: $hspeitoffEnabled
                    )
                    
                    patchCard(
                        name: "144 FPS",
                        target: "FREE FIRE • NORMAL",
                        package: "Noelx File (10).3105",
                        color: AppTheme.secondaryAccent,
                        state: $hyperBalamagicaEnabled
                    )
                    
                    patchCard(
                        name: "Aim Body",
                        target: "FREE FIRE • NORMAL",
                        package: "Noelx File (12).3105",
                        color: AppTheme.accent,
                        state: $aimBodyPackageEnabled
                    )
                    
                    patchCard(
                        name: "Aim Chest",
                        target: "FREE FIRE • NORMAL",
                        package: "Noelx File (2).3105",
                        color: AppTheme.secondaryAccent,
                        state: $aimChestPackageEnabled
                    )
                    
                    patchCard(
                        name: "Magic",
                        target: "FREE FIRE • NORMAL",
                        package: "Noelx File (14).3105",
                        color: AppTheme.accent,
                        state: $magicEnabled
                    )
                }
                .padding(.horizontal)
                
                // Apply Button
                Button(action: applyPatches) {
                    HStack {
                        if isApplying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 8)
                        }
                        Text(isApplying ? "Applying..." : "Apply Patches")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accent.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isApplying || !licenseManager.isLicensed)
                .padding(.horizontal)
                .padding(.top, 8)
                
                if !licenseManager.isLicensed {
                    Text("Please activate license to apply patches")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Patch Card
    private func patchCard(name: String, target: String, package: String, color: Color, state: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: state)
                    .toggleStyle(SwitchToggleStyle(tint: color))
                    .labelsHidden()
            }
            
            Text(target)
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
            
            Text(package)
                .font(.caption2)
                .foregroundColor(AppTheme.secondaryText.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding()
        .background(AppTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(state.wrappedValue ? color : Color.clear, lineWidth: 2)
        )
    }
    
    // MARK: - Tab Bar
    private var tabBarView: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "square.grid.2x2",
                title: "Patches",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            
            TabBarButton(
                icon: "folder",
                title: "Files",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            
            TabBarButton(
                icon: "trash",
                title: "Cleaner",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
            
            TabBarButton(
                icon: "gearshape",
                title: "Settings",
                isSelected: selectedTab == 3,
                action: { selectedTab = 3 }
            )
            
            TabBarButton(
                icon: "photo",
                title: "Wallpaper",
                isSelected: selectedTab == 4,
                action: { selectedTab = 4 }
            )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(AppTheme.surface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppTheme.border),
            alignment: .top
        )
    }
    
    // MARK: - Functions
    private func loadPatchStates() {
        aimDragEnabled = isPatchActive("Noelx File (6).3105")
        aimNeckEnabled = isPatchActive("Noelx File (7).3105")
        hspeitoffEnabled = isPatchActive("Noelx File (8).3105")
        hyperBalamagicaEnabled = isPatchActive("Noelx File (10).3105")
        aimBodyPackageEnabled = isPatchActive("Noelx File (12).3105")
        aimChestPackageEnabled = isPatchActive("Noelx File (2).3105")
        magicEnabled = isPatchActive("Noelx File (14).3105")
    }
    
    private func isPatchActive(_ package: String) -> Bool {
        // Check if patch package is installed/active
        let patchURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Patches")
            .appendingPathComponent(package)
        return patchURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }
    
    private func applyPatches() {
        guard licenseManager.isLicensed else {
            applyMessage = "Please activate your license first"
            showAlert = true
            return
        }
        
        isApplying = true
        applyMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            var successCount = 0
            var errors: [String] = []
            
            let patches: [(String, Bool)] = [
                ("Noelx File (6).3105", aimDragEnabled),
                ("Noelx File (7).3105", aimNeckEnabled),
                ("Noelx File (8).3105", hspeitoffEnabled),
                ("Noelx File (10).3105", hyperBalamagicaEnabled),
                ("Noelx File (12).3105", aimBodyPackageEnabled),
                ("Noelx File (2).3105", aimChestPackageEnabled),
                ("Noelx File (14).3105", magicEnabled)
            ]
            
            for (package, enabled) in patches {
                do {
                    try applySinglePatch(package: package, enabled: enabled)
                    successCount += 1
                } catch {
                    errors.append("\(package): \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                isApplying = false
                
                if errors.isEmpty {
                    applyMessage = "✅ Successfully applied \(successCount) patches"
                } else {
                    applyMessage = "⚠️ \(successCount) applied, \(errors.count) failed:\n\(errors.joined(separator: "\n"))"
                }
                showAlert = true
            }
        }
    }
    
    private func applySinglePatch(package: String, enabled: Bool) throws {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let patchesURL = documentsURL.appendingPathComponent("Patches")
        let packageURL = patchesURL.appendingPathComponent(package)
        
        if enabled {
            // Apply patch - copy from bundle to documents
            if let bundleURL = Bundle.main.url(forResource: package, withExtension: nil) {
                if !fileManager.fileExists(atPath: patchesURL.path) {
                    try fileManager.createDirectory(at: patchesURL, withIntermediateDirectories: true)
                }
                
                if fileManager.fileExists(atPath: packageURL.path) {
                    try fileManager.removeItem(at: packageURL)
                }
                try fileManager.copyItem(at: bundleURL, to: packageURL)
                print("✅ Applied patch: \(package)")
            } else {
                print("⚠️ Package not found in bundle: \(package)")
            }
        } else {
            // Remove patch
            if fileManager.fileExists(atPath: packageURL.path) {
                try fileManager.removeItem(at: packageURL)
                print("✅ Removed patch: \(package)")
            }
        }
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText)
        }
    }
}

#Preview {
    ContentView()
}
