import Foundation

struct PatchLibraryItem: Identifiable {
    let summary: PatchPackageSummary
    var project: PatchProject?
    var contentKey: Data?
    var packageURL: URL

    var id: UUID { summary.packageID }
    var isLocked: Bool { project == nil }

    /// Always use the filename — ignore `project.name` from inside the package.
    var displayName: String {
        packageURL.deletingPathExtension().lastPathComponent
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

    static func backupRootURL(fileManager: FileManager = .default) throws -> URL {
        let root = try packageRootURL(fileManager: fileManager)
            .appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    // MARK: - Install Bundled Packages (Sync by packageID)
    static func installBundledPackagesIfNeeded(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) {
        guard let root = try? packageRootURL(fileManager: fileManager) else {
            log("patch: failed to get package root URL")
            return
        }

        var totalInstalled = 0
        var totalReplaced = 0
        var totalRemoved = 0

        for (subdirectory, targetFolder) in [
            ("Patches/FF Normal", "FF Normal"),
            ("Patches/FF Max",    "FF Max")
        ] {
            let result = syncSubdirectory(
                subdirectory,
                targetFolder: targetFolder,
                root: root,
                bundle: bundle,
                fileManager: fileManager
            )
            totalInstalled += result.installed
            totalReplaced  += result.replaced
            totalRemoved   += result.removed
        }

        // Fallback: file .3105 tanpa subdirectory
        let fallbackURLs = bundle.urls(forResourcesWithExtension: "3105", subdirectory: nil) ?? []
        for sourceURL in fallbackURLs {
            let filename = sourceURL.lastPathComponent
            let targetFolder: String
            if filename.hasPrefix("FFM ") {
                targetFolder = "FF Max"
            } else {
                targetFolder = "FF Normal"
            }
            let targetRoot = root.appendingPathComponent(targetFolder, isDirectory: true)
            try? fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
            let destinationURL = targetRoot.appendingPathComponent(filename)

            do {
                let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
                let newSummary = try PatchPackageCodec.inspect(data)

                if let existingURL = findExistingPackageURL(
                    packageID: newSummary.packageID,
                    targetFolder: targetFolder,
                    root: root,
                    fileManager: fileManager
                ) {
                    if existingURL.path != destinationURL.path {
                        try? fileManager.removeItem(at: existingURL)
                        try data.write(to: destinationURL, options: [.atomic, .completeFileProtection])
                        totalReplaced += 1
                    } else {
                        if let existingData = try? Data(contentsOf: existingURL, options: .mappedIfSafe),
                           existingData != data {
                            try data.write(to: destinationURL, options: [.atomic, .completeFileProtection])
                            totalReplaced += 1
                        }
                    }
                } else {
                    if !fileManager.fileExists(atPath: destinationURL.path) {
                        try data.write(to: destinationURL, options: [.atomic, .completeFileProtection])
                        totalInstalled += 1
                    }
                }
            } catch {
                log("patch: skipped fallback \(filename): \(error)")
            }
        }

        log("patch: sync done — installed=\(totalInstalled), replaced=\(totalReplaced), removed=\(totalRemoved)")
    }

    /// Sync satu target folder — replace by packageID + cleanup orphans
    private static func syncSubdirectory(
        _ subdirectory: String,
        targetFolder: String,
        root: URL,
        bundle: Bundle,
        fileManager: FileManager
    ) -> (installed: Int, replaced: Int, removed: Int) {
        let targetRoot = root.appendingPathComponent(targetFolder, isDirectory: true)
        try? fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)

        guard let bundledURLs = bundle.urls(
            forResourcesWithExtension: "3105",
            subdirectory: subdirectory
        ) else {
            log("patch: no files in bundle subdirectory '\(subdirectory)'")
            return (0, 0, 0)
        }

        // Map packageID → (url, data) dari bundle
        var bundleByPackageID: [UUID: (url: URL, data: Data)] = [:]
        for sourceURL in bundledURLs {
            do {
                let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
                let summary = try PatchPackageCodec.inspect(data)
                bundleByPackageID[summary.packageID] = (sourceURL, data)
            } catch {
                log("patch: skip bundled \(sourceURL.lastPathComponent): \(error)")
            }
        }

        // Cleanup: hapus file di app yang packageID-nya tidak ada di bundle baru
        var removed = 0
        if let existing = try? fileManager.contentsOfDirectory(
            at: targetRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) {
            for existingURL in existing where existingURL.pathExtension.lowercased() == "3105" {
                guard let data = try? Data(contentsOf: existingURL, options: .mappedIfSafe),
                      let summary = try? PatchPackageCodec.inspect(data) else {
                    // File corrupt → hapus
                    try? fileManager.removeItem(at: existingURL)
                    removed += 1
                    continue
                }
                if bundleByPackageID[summary.packageID] == nil {
                    // Patch tidak ada lagi di bundle → hapus
                    try? fileManager.removeItem(at: existingURL)
                    try? PatchKeyStore.delete(for: summary)
                    log("patch: removed orphan \(existingURL.lastPathComponent)")
                    removed += 1
                }
            }
        }

        // Install / replace
        var installed = 0
        var replaced = 0
        for (packageID, entry) in bundleByPackageID {
            let filename = entry.url.lastPathComponent
            let destinationURL = targetRoot.appendingPathComponent(filename)

            let existingURL = findExistingPackageURL(
                packageID: packageID,
                targetFolder: targetFolder,
                root: root,
                fileManager: fileManager
            )

            if let existingURL {
                // Sudah ada — cek data sama atau tidak
                if let existingData = try? Data(contentsOf: existingURL, options: .mappedIfSafe),
                   existingData == entry.data {
                    // Identik — skip
                    continue
                }
                // Beda → replace
                if existingURL.path != destinationURL.path {
                    try? fileManager.removeItem(at: existingURL)
                }
                do {
                    try entry.data.write(to: destinationURL, options: [.atomic, .completeFileProtection])
                    replaced += 1
                    log("patch: replaced \(targetFolder)/\(filename)")
                } catch {
                    log("patch: failed replace \(filename): \(error)")
                }
            } else {
                // Belum ada → install
                do {
                    try entry.data.write(to: destinationURL, options: [.atomic, .completeFileProtection])
                    installed += 1
                    log("patch: installed \(targetFolder)/\(filename)")
                } catch {
                    log("patch: failed install \(filename): \(error)")
                }
            }
        }

        return (installed, replaced, removed)
    }

    /// Cari file .3105 di app berdasarkan packageID
    private static func findExistingPackageURL(
        packageID: UUID,
        targetFolder: String,
        root: URL,
        fileManager: FileManager
    ) -> URL? {
        let targetRoot = root.appendingPathComponent(targetFolder, isDirectory: true)
        guard let files = try? fileManager.contentsOfDirectory(
            at: targetRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return nil }

        for fileURL in files where fileURL.pathExtension.lowercased() == "3105" {
            guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
                  let summary = try? PatchPackageCodec.inspect(data) else { continue }
            if summary.packageID == packageID {
                return fileURL
            }
        }
        return nil
    }

    // MARK: - Load Patches (Filter by Target)
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

                let item = PatchLibraryItem(
                    summary: summary,
                    project: decoded?.project,
                    contentKey: decoded?.contentKey,
                    packageURL: url
                )

                if summary.schemaVersion >= 2, let project = decoded?.project {
                    do {
                        _ = try PatchWorkspaceService.ensureWorkspace(for: project)
                    } catch {
                        log("patch: workspace unavailable for \(project.id.uuidString)")
                    }
                }
                byID[summary.packageID] = item
                log("patch: loaded \(url.lastPathComponent)")
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
