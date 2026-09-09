//
//  PatchProjectLibrary.swift
//  ExternalNoelx
//
//  Created by User on 22/03/25.
//

import Foundation
import SwiftUI

struct PatchLibraryItem: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let project: PatchProject?
    let isImported: Bool
    
    var displayName: String {
        guard !isImported else { return name }
        if name.hasPrefix("Noelx File (") {
            return project?.name ?? name
        }
        return project?.name ?? name
    }
}

enum PatchProjectLibrary {
    static let sharedDirectory: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("PatchLibrary", isDirectory: true)
    }()
    
    static let importedDirectory: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("ImportedPatches", isDirectory: true)
    }()
    
    static func listAllItems(fileManager: FileManager = .default) -> [PatchLibraryItem] {
        var items: [PatchLibraryItem] = []
        
        // List imported patches
        do {
            let importedURLs = try fileManager.contentsOfDirectory(
                at: importedDirectory,
                includingPropertiesForKeys: nil
            )
            for url in importedURLs where url.pathExtension == "3105" {
                let project = loadProject(from: url)
                items.append(PatchLibraryItem(
                    name: url.deletingPathExtension().lastPathComponent,
                    url: url,
                    project: project,
                    isImported: true
                ))
            }
        } catch {
            print("Failed to list imported patches: \(error)")
        }
        
        // List built-in patches from bundle
        if let bundleURLs = Bundle.main.urls(forResourcesWithExtension: "3105", subdirectory: "Patches") {
            for url in bundleURLs {
                // Check if this built-in patch is already imported
                let imported = items.contains { $0.url.lastPathComponent == url.lastPathComponent }
                if !imported {
                    let project = loadProject(from: url)
                    items.append(PatchLibraryItem(
                        name: url.deletingPathExtension().lastPathComponent,
                        url: url,
                        project: project,
                        isImported: false
                    ))
                }
            }
        }
        
        // Also check the Patches folder for copied patches
        let patchesDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Patches")
        if fileManager.fileExists(atPath: patchesDir.path) {
            do {
                let patchURLs = try fileManager.contentsOfDirectory(at: patchesDir, includingPropertiesForKeys: nil)
                for url in patchURLs where url.pathExtension == "3105" {
                    let alreadyExists = items.contains { $0.url.lastPathComponent == url.lastPathComponent }
                    if !alreadyExists {
                        let project = loadProject(from: url)
                        items.append(PatchLibraryItem(
                            name: url.deletingPathExtension().lastPathComponent,
                            url: url,
                            project: project,
                            isImported: true
                        ))
                    }
                }
            } catch {
                print("Failed to list Patches directory: \(error)")
            }
        }
        
        return items.sorted { $0.displayName < $1.displayName }
    }
    
    static func loadProject(from url: URL) -> PatchProject? {
        // Try to parse the package file to get project info
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PatchProject.self, from: data)
    }
    
    static func readPackage(at url: URL) throws -> Data {
        return try Data(contentsOf: url)
    }
    
    static func save(
        _ data: Data,
        name: String,
        to directory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let safeName = sanitizedFilename(name)
        let destination = directory.appendingPathComponent(safeName)
        
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        try data.write(to: destination)
        return destination
    }
    
    static func installImportedPackage(
        from sourceURL: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let fileName = sourceURL.lastPathComponent
        let destination = importedDirectory.appendingPathComponent(fileName)
        
        if !fileManager.fileExists(atPath: importedDirectory.path) {
            try fileManager.createDirectory(at: importedDirectory, withIntermediateDirectories: true)
        }
        
        // If file already exists, remove it
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        
        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }
    
    static func delete(_ item: PatchLibraryItem, fileManager: FileManager = .default) throws {
        if fileManager.fileExists(atPath: item.url.path) {
            try fileManager.removeItem(at: item.url)
        }
    }
    
    static func synchronizeWorkspace(
        fileManager: FileManager = .default
    ) throws -> [PatchLibraryItem] {
        // Ensure directories exist
        if !fileManager.fileExists(atPath: sharedDirectory.path) {
            try fileManager.createDirectory(at: sharedDirectory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: importedDirectory.path) {
            try fileManager.createDirectory(at: importedDirectory, withIntermediateDirectories: true)
        }
        
        // Clean up orphaned files
        let allItems = listAllItems(fileManager: fileManager)
        
        // Sync workspace - copy imported patches to shared directory
        for item in allItems where item.isImported {
            let destination = sharedDirectory.appendingPathComponent(item.url.lastPathComponent)
            if !fileManager.fileExists(atPath: destination.path) {
                try fileManager.copyItem(at: item.url, to: destination)
            }
        }
        
        return allItems
    }
    
    private static func sanitizedFilename(_ rawName: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return rawName
            .components(separatedBy: invalidChars)
            .joined(separator: "_")
            .appending(".3105")
    }
}
