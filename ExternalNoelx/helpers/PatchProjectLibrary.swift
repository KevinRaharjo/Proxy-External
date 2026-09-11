import Foundation

struct PatchLibraryItem: Identifiable {
    let summary: PatchPackageSummary
    var project: PatchProject?
    var contentKey: Data?
    var packageURL: URL

    var id: UUID { summary.packageID }
    var isLocked: Bool { project == nil }
    var displayName: String {
        let filename = packageURL.deletingPathExtension().lastPathComponent
        return project?.name ?? filename
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

    // MARK: - Install Bundled Packages (Support Folder Reference)
    static func installBundledPackagesIfNeeded(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) {
        guard let root = try? packageRootURL(fileManager: fileManager) else {
            log("patch: failed to get package root URL")
            return
        }

        // 🔥 CARI SEMUA FILE .3105 DI BUNDLE (folder reference)
        // Folder reference di Xcode jadi folder `Patches` di dalam bundle
        // Isi subfolder:
        //   - Patches/FF Normal/*.3105
        //   - Patches/FF Max/*.3105
        
        var totalInstalled = 0
        
        // Cari di subfolder "Patches/FF Normal"
        totalInstalled += installFromSubdirectory(
            "Patches/FF Normal",
            targetFolder: "FF Normal",
            root: root,
            bundle: bundle,
            fileManager: fileManager
        )
        
        // Cari di subfolder "Patches/FF Max"
        totalInstalled += installFromSubdirectory(
            "Patches/FF Max",
            targetFolder: "FF Max",
            root: root,
            bundle: bundle,
            fileManager: fileManager
        )
        
        // Fallback: cari di root bundle (kalo Xcode flatten folder)
        let fallbackURLs = bundle.urls(forResourcesWithExtension: "3105", subdirectory: nil) ?? []
        if !fallbackURLs.isEmpty {
            for sourceURL in fallbackURLs {
                // Tentukan target folder dari nama file
                let filename = sourceURL.lastPathComponent
                let targetFolder: String
                if filename.hasPrefix("FFM ") {
                    targetFolder = "FF Max"
                } else if filename.hasPrefix("FFN ") || filename.hasPrefix("Noexk File") {
                    targetFolder = "FF Normal"
                } else {
                    targetFolder = "FF Normal"
                }
                
                let targetRoot = root.appendingPathComponent(targetFolder, isDirectory: true)
                try? fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
                let destinationURL = targetRoot.appendingPathComponent(filename)
                
                guard !fileManager.fileExists(atPath: destinationURL.path) else { continue }
                do {
                    let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
                    _ = try PatchPackageCodec.inspect(data)
                    try data.write(to: destinationURL, options: [.atomic, .completeFileProtection])
                    totalInstalled += 1
                    log("patch: installed fallback \(filename)")
                } catch {
                    log("patch: skipped fallback \(filename): \(error)")
                }
            }
        }
        
        log("patch: total installed bundled packages = \(totalInstalled)")
    }
    
    // MARK: - Helper: Install from Subdirectory
    private static func installFromSubdirectory(
        _ subdirectory: String,
        targetFolder: String,
        root: URL,
        bundle: Bundle,
        fileManager: FileManager
    ) -> Int {
        let targetRoot = root.appendingPathComponent(targetFolder, isDirectory: true)
        try? fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        
        // Cari file .3105 di subfolder
        guard let urls = bundle.urls(forResourcesWithExtension: "3105", subdirectory: subdirectory) else {
            log("patch: no files found in bundle subdirectory '\(subdirectory)'")
            return 0
        }
        
        var installed = 0
        for sourceURL in urls {
            let filename = sourceURL.lastPathComponent
            let destinationURL = targetRoot.appendingPathComponent(filename)
            
            guard !fileManager.fileExists(atPath: destinationURL.path) else { continue }
            
            do {
                let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
                _ = try PatchPackageCodec.inspect(data)
                try data.write(to: destinationURL, options: [.atomic, .completeFileProtection])
                installed += 1
                log("patch: installed \(targetFolder)/\(filename)")
            } catch {
                log("patch: skipped \(targetFolder)/\(filename): \(error)")
            }
        }
        
        log("patch: installed \(installed) files from '\(subdirectory)'")
        return installed
    }

    // MARK: - Load Patches (Filter by Target)
    static func load(target: String = "FF Normal", fileManager: FileManager = .default) -> [PatchLibraryItem] {
        guard let root = try? packageRootURL(fileManager: fileManager) else { return [] }
        
        // Cari folder target
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
                    // Coba decode pake bundled resource password
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
