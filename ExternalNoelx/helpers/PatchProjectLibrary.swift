import Foundation
import CryptoKit

struct PatchLibraryItem: Identifiable {
    let summary: PatchPackageSummary
    var project: PatchProject?
    var contentKey: Data?
    var packageURL: URL
    var overrideDisplayName: String?

    var id: UUID { summary.packageID }
    var isLocked: Bool { project == nil }

    var displayName: String {
        if let overrideDisplayName, !overrideDisplayName.isEmpty {
            return overrideDisplayName
        }
        return packageURL.deletingPathExtension().lastPathComponent
    }

    var workspaceURL: URL? {
        PatchWorkspaceService.workspaceURL(projectID: id)
    }
}

struct PatchPasswordRequest: Identifiable {
    let summary: PatchPackageSummary
    var id: UUID { summary.packageID }
}

enum PatchProjectLibrary {
    static func packageRootURL(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent("PatchProjects", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func ensurePatchesDirectory(fileManager: FileManager = .default) throws -> URL {
        let root = try packageRootURL(fileManager: fileManager)
        for folder in ["FF Normal", "FF Max"] {
            let sub = root.appendingPathComponent(folder, isDirectory: true)
            try fileManager.createDirectory(at: sub, withIntermediateDirectories: true)
        }
        return root
    }

    static func backupRootURL(fileManager: FileManager = .default) throws -> URL {
        let root = try packageRootURL(fileManager: fileManager)
            .appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    // MARK: - Display Name Mapping

    private static let displayNameMapKey = "patch.displayNameMap.v1"

    static func loadDisplayNameMap() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: displayNameMapKey),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    static func saveDisplayNameMap(_ map: [String: String]) {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: displayNameMapKey)
        }
    }

    static func displayName(for packageURL: URL) -> String? {
        let filename = packageURL.lastPathComponent
        return loadDisplayNameMap()[filename]
    }

    // MARK: - Install Bundled Packages

    static func installBundledPackagesIfNeeded(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) {
        guard let root = try? packageRootURL(fileManager: fileManager) else {
            log("patch: failed to get package root URL")
            return
        }

        let migrationKey = "patches.migratedToAppSupport.v1"
        let alreadyMigrated = UserDefaults.standard.bool(forKey: migrationKey)

        if !alreadyMigrated {
            let bundledPatches = bundle.bundleURL.appendingPathComponent("Patches", isDirectory: true)
            if fileManager.fileExists(atPath: bundledPatches.path) {
                do {
                    let bundledFiles = try fileManager.contentsOfDirectory(
                        at: bundledPatches,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )
                    for subfolder in bundledFiles {
                        let values = try subfolder.resourceValues(forKeys: [.isDirectoryKey])
                        guard values.isDirectory == true else { continue }

                        let targetFolder = root.appendingPathComponent(
                            subfolder.lastPathComponent,
                            isDirectory: true
                        )
                        try fileManager.createDirectory(
                            at: targetFolder,
                            withIntermediateDirectories: true
                        )

                        let patchFiles = try fileManager.contentsOfDirectory(
                            at: subfolder,
                            includingPropertiesForKeys: nil,
                            options: [.skipsHiddenFiles]
                        )
                        for patchFile in patchFiles where patchFile.pathExtension.lowercased() == "3105" {
                            let dest = targetFolder.appendingPathComponent(patchFile.lastPathComponent)
                            if !fileManager.fileExists(atPath: dest.path) {
                                try fileManager.copyItem(at: patchFile, to: dest)
                                log("patch: migrated \(patchFile.lastPathComponent)")
                            }
                        }
                    }
                    UserDefaults.standard.set(true, forKey: migrationKey)
                    log("patch: migration from bundle to Application Support complete")
                } catch {
                    log("patch: migration failed: \(error.localizedDescription)")
                }
            } else {
                log("patch: no bundled Patches/ folder found (clean IPA)")
                UserDefaults.standard.set(true, forKey: migrationKey)
            }
        }
    }

    // MARK: - Sync from Server

    static func syncPatchesFromServer(
        deviceID: String,
        license: String,
        fileManager: FileManager = .default
    ) async throws {
        log("patch-sync: starting sync for device \(deviceID.prefix(8))...")

        let serverPatches = try await APIClient.shared.fetchPatchList(
            deviceID: deviceID,
            license: license
        )

        log("patch-sync: server returned \(serverPatches.count) patches")

        guard let root = try? packageRootURL(fileManager: fileManager) else {
            throw PatchPackageError.invalidProject
        }

        var syncedFilenames = Set<String>()
        var displayNameMap = loadDisplayNameMap()

        for meta in serverPatches {
            let targetFolder = root.appendingPathComponent(meta.target, isDirectory: true)
            try fileManager.createDirectory(at: targetFolder, withIntermediateDirectories: true)
            let localURL = targetFolder.appendingPathComponent(meta.filename)
            syncedFilenames.insert(meta.filename)

            // Update mapping
            displayNameMap[meta.filename] = meta.displayName

            // Check existing file
            if fileManager.fileExists(atPath: localURL.path) {
                if let localData = try? Data(contentsOf: localURL),
                   sha256Hex(localData) == meta.checksum {
                    log("patch-sync: skip \(meta.filename) (up to date)")
                    continue
                } else {
                    log("patch-sync: update \(meta.filename) (checksum mismatch)")
                }
            } else {
                log("patch-sync: download \(meta.filename) (\(meta.size) bytes)")
            }

            do {
                let data = try await APIClient.shared.downloadPatch(
                    id: meta.id,
                    deviceID: deviceID,
                    license: license
                )

                let downloadedChecksum = sha256Hex(data)
                guard downloadedChecksum == meta.checksum else {
                    log("patch-sync: checksum mismatch for \(meta.filename)")
                    continue
                }

                try data.write(to: localURL, options: [.atomic, .completeFileProtection])
                log("patch-sync: saved \(meta.filename) (\(data.count) bytes)")
            } catch {
                log("patch-sync: failed to download \(meta.filename): \(error.localizedDescription)")
            }
        }

        // Cleanup orphans
        for folder in ["FF Normal", "FF Max"] {
            let folderURL = root.appendingPathComponent(folder, isDirectory: true)
            guard let files = try? fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files where file.pathExtension.lowercased() == "3105" {
                if !syncedFilenames.contains(file.lastPathComponent) {
                    try? fileManager.removeItem(at: file)
                    displayNameMap.removeValue(forKey: file.lastPathComponent)
                    log("patch-sync: removed orphan \(file.lastPathComponent)")
                }
            }
        }

        saveDisplayNameMap(displayNameMap)
        log("patch-sync: complete — \(syncedFilenames.count) patches synced")
    }

    private static func sha256Hex(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Load Patches

    static func load(target: String = "FF Normal", fileManager: FileManager = .default) -> [PatchLibraryItem] {
        guard let root = try? packageRootURL(fileManager: fileManager) else { return [] }

        let targetFolder = root.appendingPathComponent(target, isDirectory: true)
        let searchURL = fileManager.fileExists(atPath: targetFolder.path) ? targetFolder : root

        log("patch: loading from \(searchURL.path)")

        guard let urls = try? fileManager.contentsOfDirectory(
            at: searchURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return [] }

        var byID: [UUID: PatchLibraryItem] = [:]
        for url in urls where url.pathExtension.lowercased() == "3105" {
            do {
                let data = try readPackage(at: url)
                let summary = try PatchPackageCodec.inspect(data)
                let decoded: DecodedPatchPackage?

                if let contentKey = try PatchKeyStore.load(for: summary) {
                    decoded = try PatchPackageCodec.decode(data, contentKey: contentKey)
                } else if summary.isPasswordProtected {
                    do {
                        let bundled = try PatchPackageCodec.decode(
                            data,
                            password: PatchPackageCodec.bundledResourcePassword
                        )
                        try PatchKeyStore.store(bundled.contentKey, for: summary)
                        decoded = bundled
                    } catch {
                        log("patch: could not decode \(url.lastPathComponent) with bundled password")
                        decoded = nil
                    }
                } else {
                    decoded = try PatchPackageCodec.decode(data, password: nil)
                }

                let overrideName = displayName(for: url)
                let item = PatchLibraryItem(
                    summary: summary,
                    project: decoded?.project,
                    contentKey: decoded?.contentKey,
                    packageURL: url,
                    overrideDisplayName: overrideName
                )

                if summary.schemaVersion >= 2, let project = decoded?.project {
                    do {
                        _ = try PatchWorkspaceService.ensureWorkspace(for: project)
                    } catch {
                        log("patch: workspace unavailable for \(project.id.uuidString)")
                    }
                }
                byID[summary.packageID] = item
                log("patch: loaded \(overrideName ?? url.lastPathComponent)")
            } catch {
                log("patch: skipped invalid local package \(url.lastPathComponent)")
            }
        }

        log("patch: total loaded = \(byID.count) from \(target)")
        return byID.values.sorted {
            ($0.project?.updatedAt ?? .distantPast) > ($1.project?.updatedAt ?? .distantPast)
        }
    }

    static func readPackage(at url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isDirectory != true,
              values.isSymbolicLink != true,
              values.isRegularFile == true else {
            throw PatchPackageError.invalidProject
        }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    static func save(
        data: Data,
        projectName: String,
        existingURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        let destination: URL
        if let existingURL {
            destination = existingURL
        } else {
            let root = try packageRootURL(fileManager: fileManager)
            let baseName = sanitizedFilename(projectName)
            var candidate = root.appendingPathComponent(baseName).appendingPathExtension("3105")
            var suffix = 2
            while fileManager.fileExists(atPath: candidate.path) {
                candidate = root.appendingPathComponent("\(baseName)-\(suffix)").appendingPathExtension("3105")
                suffix += 1
            }
            destination = candidate
        }
        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        return destination
    }

    static func installImportedPackage(
        data: Data,
        decoded: DecodedPatchPackage,
        summary: PatchPackageSummary,
        existingURL: URL?,
        fileManager: FileManager = .default
    ) throws {
        let previousData = try existingURL.map { try readPackage(at: $0) }
        var savedURL: URL?
        do {
            savedURL = try save(
                data: data,
                projectName: decoded.project.name,
                existingURL: existingURL,
                fileManager: fileManager
            )
            if summary.schemaVersion >= 2 {
                _ = try PatchWorkspaceService.replaceWorkspace(
                    with: decoded.project,
                    fileManager: fileManager
                )
            } else {
                try? PatchWorkspaceService.deleteWorkspace(
                    projectID: decoded.project.id,
                    fileManager: fileManager
                )
            }
        } catch {
            if let previousData, let existingURL {
                try? previousData.write(
                    to: existingURL,
                    options: [.atomic, .completeFileProtection]
                )
            } else if let savedURL, fileManager.fileExists(atPath: savedURL.path) {
                try? fileManager.removeItem(at: savedURL)
            }
            throw error
        }
    }

    static func delete(_ item: PatchLibraryItem, fileManager: FileManager = .default) throws {
        // Remove from display name map
        var map = loadDisplayNameMap()
        map.removeValue(forKey: item.packageURL.lastPathComponent)
        saveDisplayNameMap(map)

        if fileManager.fileExists(atPath: item.packageURL.path) {
            try fileManager.removeItem(at: item.packageURL)
        }
        try? PatchWorkspaceService.deleteWorkspace(projectID: item.id, fileManager: fileManager)
        try? PatchKeyStore.delete(for: item.summary)
    }

    static func synchronizeWorkspace(
        item: PatchLibraryItem,
        fileManager: FileManager = .default
    ) throws -> PatchProject {
        guard item.summary.schemaVersion >= 2,
              let baseProject = item.project,
              let contentKey = item.contentKey else {
            throw PatchPackageError.invalidProject
        }
        let workspace = try PatchWorkspaceService.ensureWorkspace(
            for: baseProject,
            fileManager: fileManager
        )
        let project = try PatchWorkspaceService.snapshot(
            baseProject: baseProject,
            workspaceURL: workspace,
            fileManager: fileManager
        )
        let original = try readPackage(at: item.packageURL)
        let updated = try PatchPackageCodec.update(
            original,
            project: project,
            contentKey: contentKey,
            schemaVersion: PatchPackageCodec.latestSchemaVersion
        )
        _ = try save(
            data: updated,
            projectName: project.name,
            existingURL: item.packageURL,
            fileManager: fileManager
        )
        return project
    }

    private static func sanitizedFilename(_ rawName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let scalars = rawName.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let result = String(scalars)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)
        return result.isEmpty ? "Patch" : String(result)
    }
}
