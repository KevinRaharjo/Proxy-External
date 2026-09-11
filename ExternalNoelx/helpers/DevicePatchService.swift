import Foundation

enum DevicePatchService {
    private static let fileManager = FileManager.default
    
    // MARK: - Apply Patch
    
    static func apply(project: PatchProject) throws -> PatchTransactionReceipt {
        let bundleIDs = orderedBundleIdentifiers(in: project)
        
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            // Backup semua file yang akan di-patch
            for rule in project.rules {
                guard let root = roots[rule.bundleID] else { continue }
                let targetPath = root.appendingPathComponent(rule.relativePath).path
                
                if fileManager.fileExists(atPath: targetPath) {
                    _ = try backupFile(at: targetPath, for: project.id)
                }
            }
            
            // Apply patch pakai PatchTransaction
            let receipt = try PatchTransaction.apply(
                project: project,
                backupRoot: try PatchProjectLibrary.backupRootURL(),
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
            
            saveReceipt(receipt)
            return receipt
        }
    }
    
    // MARK: - Restore Patch (ANTI-ERROR)
    
    static func restore(receipt: PatchTransactionReceipt) throws {
        do {
            let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
            
            try withResolvedContainers(bundleIDs: bundleIDs) { roots in
                // Coba restore dari backup
                for (bundleID, root) in roots {
                    let backupDir = try backupDirURL(for: receipt.projectID)
                    
                    if fileManager.fileExists(atPath: backupDir.path) {
                        let backupFiles = try fileManager.contentsOfDirectory(
                            at: backupDir,
                            includingPropertiesForKeys: nil
                        )
                        
                        for backupFile in backupFiles {
                            let originalName = backupFile.deletingPathExtension().lastPathComponent
                            
                            // Cari file target di container
                            let targetPath = findTargetPath(
                                for: originalName,
                                in: root,
                                projectID: receipt.projectID
                            )
                            
                            if let targetPath = targetPath {
                                try restoreFile(from: backupFile, to: targetPath)
                            }
                        }
                    }
                }
                
                // Jalankan PatchTransaction.restore juga
                try? PatchTransaction.restore(
                    receipt: receipt,
                    containerResolver: { bundleID in
                        guard let root = roots[bundleID] else {
                            throw PatchPackageError.targetAppUnavailable(bundleID)
                        }
                        return root
                    }
                )
            }
            
            // Hapus backup & receipt
            try? fileManager.removeItem(at: try backupDirURL(for: receipt.projectID))
            removeReceipt(projectID: receipt.projectID)
            
        } catch {
            // Kalo restore gagal, tetap hapus receipt biar gak nyangkut
            print("⚠️ Restore failed: \(error)")
            removeReceipt(projectID: receipt.projectID)
            throw error
        }
    }
    
    // MARK: - Backup Helpers
    
    private static func backupDirURL(for projectID: UUID) throws -> URL {
        let backupRoot = try PatchProjectLibrary.backupRootURL()
        let backupDir = backupRoot.appendingPathComponent(projectID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        return backupDir
    }
    
    private static func backupFile(at path: String, for projectID: UUID) throws -> URL {
        let backupDir = try backupDirURL(for: projectID)
        let fileName = (path as NSString).lastPathComponent
        let backupPath = backupDir.appendingPathComponent("\(fileName).backup")
        
        if fileManager.fileExists(atPath: backupPath.path) {
            try? fileManager.removeItem(at: backupPath)
        }
        
        try fileManager.copyItem(atPath: path, toPath: backupPath.path)
        print("✅ Backup: \(fileName)")
        return backupPath
    }
    
    private static func restoreFile(from backupPath: URL, to targetPath: String) throws {
        if fileManager.fileExists(atPath: targetPath) {
            try? fileManager.removeItem(atPath: targetPath)
        }
        try fileManager.copyItem(atPath: backupPath.path, toPath: targetPath)
        print("✅ Restored: \((targetPath as NSString).lastPathComponent)")
    }
    
    private static func findTargetPath(for fileName: String, in root: URL, projectID: UUID) -> String? {
        // Cari file di container root
        let directPath = root.appendingPathComponent(fileName).path
        if fileManager.fileExists(atPath: directPath) {
            return directPath
        }
        
        // Cari di subfolder umum
        let commonPaths = [
            "Documents/\(fileName)",
            "Library/Caches/\(fileName)",
            "Library/Application Support/\(fileName)",
            "tmp/\(fileName)"
        ]
        
        for relativePath in commonPaths {
            let fullPath = root.appendingPathComponent(relativePath).path
            if fileManager.fileExists(atPath: fullPath) {
                return fullPath
            }
        }
        
        return nil
    }
    
    // MARK: - Reset All
    
    static func resetAllPatches() throws {
        let backupRoot = try PatchProjectLibrary.backupRootURL()
        try? fileManager.removeItem(at: backupRoot)
        
        // Hapus semua receipt dari UserDefaults
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("receipt_") {
                defaults.removeObject(forKey: key)
            }
        }
        
        print("✅ All patches reset")
    }
    
    // MARK: - Receipt Management
    
    private static func saveReceipt(_ receipt: PatchTransactionReceipt) {
        let key = "receipt_\(receipt.projectID.uuidString)"
        if let data = try? JSONEncoder().encode(receipt) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    static func latestReceipt(projectID: UUID) -> PatchTransactionReceipt? {
        let key = "receipt_\(projectID.uuidString)"
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PatchTransactionReceipt.self, from: data)
    }
    
    static func removeReceipt(projectID: UUID) {
        let key = "receipt_\(projectID.uuidString)"
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    // MARK: - Container Helpers
    
    private static func orderedBundleIdentifiers(in project: PatchProject) -> [String] {
        project.allBundleIdentifiers
    }
    
    private static func withResolvedContainers<T>(
        bundleIDs: [String],
        operation: ([String: URL]) throws -> T
    ) throws -> T {
        var roots: [String: URL] = [:]
        
        for bundleID in bundleIDs {
            guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
                  ContainerStore.isApplicationContainerPath(path) else {
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(
                URL(fileURLWithPath: path, isDirectory: true)
            )
        }
        return try operation(roots)
    }
}
