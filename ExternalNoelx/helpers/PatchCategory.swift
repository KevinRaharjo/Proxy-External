import SwiftUI

// Patch category — derived from the filename prefix.
// AIM-xxx.3105 → .aim
// ESP-xxx.3105 → .esp
// MISC-xxx.3105 → .misc
// Anything else defaults to .aim.

enum PatchCategory: String, CaseIterable, Identifiable {
    case aim = "AIM"
    case esp = "ESP"
    case misc = "MISC"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .aim:  return "scope"
        case .esp:  return "eye.fill"
        case .misc: return "sparkles"
        }
    }

    /// Subtle per-category tint used by the segmented control glow.
    /// All stay in the blue family (no red/purple/green) to keep the
    /// VANTA look consistent.
    var tint: Color {
        switch self {
        case .aim:  return AppTheme.accent
        case .esp:  return AppTheme.accentBright
        case .misc: return AppTheme.accentDeep
        }
    }
}

extension PatchLibraryItem {
    var category: PatchCategory {
        let name = displayName.uppercased()
        if name.hasPrefix("ESP")  { return .esp }
        if name.hasPrefix("MISC") { return .misc }
        if name.hasPrefix("AIM")  { return .aim }
        return .aim   // default for unmatched
    }
}
