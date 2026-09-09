// ✅ BENAR - DevicePatchService.swift
import Foundation

enum DevicePatchService {
    private static let fileManager = FileManager.default
    
    // MARK: - Backup & Restore
    
    static func backupOriginalFile(at path: String) throws -> URL {
        let backupRoot = try PatchProjectLibrary.backupRootURL()
        let backupDir = backupRoot.appendingPathComponent("originals", isDirectory: true)
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        
        let fileName = (path as NSString).lastPathComponent
        let backupPath = backupDir.appendingPathComponent("\(fileName).backup")
        
        if fileManager.fileExists(atPath: path) {
            if fileManager.fileExists(atPath: backupPath.path) {
                try fileManager.removeItem(at: backupPath)
            }
            try fileManager.copyItem(atPath: path, toPath: backupPath.path)
            print("✅ Backup created: \(backupPath.path)")
        }
        return backupPath
    }
    
    static func restoreOriginalFile(from backupPath: URL, to targetPath: String) throws {
        guard fileManager.fileExists(atPath: backupPath.path) else {
            print("⚠️ Backup file not found: \(backupPath.path)")
            return
        }
        
        if fileManager.fileExists(atPath: targetPath) {
            try fileManager.removeItem(atPath: targetPath)
        }
        
        try fileManager.copyItem(atPath: backupPath.path, toPath: targetPath)
        print("✅ Restored: \(targetPath)")
    }
    
    static func restoreOriginalFile(for projectID: UUID, filePath: String) throws {
        let backupRoot = try PatchProjectLibrary.backupRootURL()
        let backupDir = backupRoot.appendingPathComponent("originals", isDirectory: true)
        let fileName = (filePath as NSString).lastPathComponent
        let backupPath = backupDir.appendingPathComponent("\(fileName).backup")
        
        try restoreOriginalFile(from: backupPath, to: filePath)
    }
    
    // MARK: - Apply Patch dengan Backup
    
    static func apply(project: PatchProject) throws -> PatchTransactionReceipt {
        let bundleIDs = orderedBundleIdentifiers(in: project)
        
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            // Backup semua file yang akan di-patch
            for rule in project.rules {
                guard let root = roots[rule.bundleID] else { continue }
                let targetPath = root.appendingPathComponent(rule.relativePath).path
                
                if fileManager.fileExists(atPath: targetPath) {
                    try backupOriginalFile(at: targetPath)
                }
            }
            
            // Apply patch
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
            
            // Simpan receipt untuk restore nanti
            saveReceipt(receipt)
            return receipt
        }
    }
    
    // MARK: - Restore Patch (Otomatis)
    
    static func restore(receipt: PatchTransactionReceipt) throws {
        // Restore original files
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            // Coba restore dari backup
            for (bundleID, root) in roots {
                let backupRoot = try PatchProjectLibrary.backupRootURL()
                let backupDir = backupRoot.appendingPathComponent("originals", isDirectory: true)
                let backupFiles = try fileManager.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
                
                for backupFile in backupFiles {
                    let fileName = backupFile.deletingPathExtension().lastPathComponent
                    let targetPath = root.appendingPathComponent(fileName).path
                    
                    if fileManager.fileExists(atPath: targetPath) {
                        try restoreOriginalFile(from: backupFile, to: targetPath)
                    }
                }
            }
            
            // Hapus backup setelah restore
            let backupRoot = try PatchProjectLibrary.backupRootURL()
            let backupDir = backupRoot.appendingPathComponent("originals", isDirectory: true)
            try? fileManager.removeItem(at: backupDir)
            
            // Hapus receipt
            removeReceipt(projectID: receipt.projectID)
        }
        
        // Juga jalankan PatchTransaction.restore
        try PatchTransaction.restore(
            receipt: receipt,
            containerResolver: { bundleID in
                guard let root = roots[bundleID] else {
                    throw PatchPackageError.targetAppUnavailable(bundleID)
                }
                return root
            }
        )
    }
    
    // MARK: - Reset All Patches (Bersihin semua)
    
    static func resetAllPatches() throws {
        // Hapus semua backup
        let backupRoot = try PatchProjectLibrary.backupRootURL()
        let backupDir = backupRoot.appendingPathComponent("originals", isDirectory: true)
        try? fileManager.removeItem(at: backupDir)
        
        // Hapus semua receipt
        let receipts = try fileManager.contentsOfDirectory(at: backupRoot, includingPropertiesForKeys: nil)
        for receipt in receipts {
            try? fileManager.removeItem(at: receipt)
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
            roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        }
        return try operation(roots)
    }
}

// MARK: - Receipt Codable
extension PatchTransactionReceipt: Codable {}
