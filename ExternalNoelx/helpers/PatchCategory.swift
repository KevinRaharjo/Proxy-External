import Foundation

// Patch category — derived from the filename prefix.
// AIM-xxx.3105 → .aim
// ESP-xxx.3105 → .esp
// Anything else defaults to .aim.

enum PatchCategory: String, CaseIterable, Identifiable {
    case aim = "AIM"
    case esp = "ESP"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .aim: return "scope"
        case .esp: return "eye.fill"
        }
    }
}

extension PatchLibraryItem {
    var category: PatchCategory {
        let name = displayName.uppercased()
        if name.hasPrefix("ESP") { return .esp }
        if name.hasPrefix("AIM") { return .aim }
        return .aim   // default for unmatched
    }
}
