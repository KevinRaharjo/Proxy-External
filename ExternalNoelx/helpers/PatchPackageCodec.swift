//
//  PatchPackageCodec.swift
//  ExternalNoelx
//
//  Created by User on 22/03/25.
//

import Foundation

struct PatchProject: Codable {
    let id: String
    let name: String
    let version: String
    let description: String?
    let author: String?
    let targetApp: String?
    let targetVersion: String?
    let files: [PatchFile]
    let dependencies: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case version
        case description
        case author
        case targetApp = "target_app"
        case targetVersion = "target_version"
        case files
        case dependencies
    }
}

struct PatchFile: Codable {
    let path: String
    let destination: String
    let permissions: Int?
    let type: FileType
    
    enum FileType: String, Codable {
        case file
        case directory
        case symlink
    }
}

struct PatchPackageCodec {
    static func decode(_ data: Data) throws -> PatchProject {
        let decoder = JSONDecoder()
        return try decoder.decode(PatchProject.self, from: data)
    }
    
    static func encode(_ project: PatchProject) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(project)
    }
}
