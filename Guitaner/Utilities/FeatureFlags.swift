import Foundation

/// Toggleable features. Each flag has a built-in default and can be overridden
/// at runtime (stored in UserDefaults) — e.g. from a future debug/settings screen.
enum FeatureFlag: String, CaseIterable {
    case chordDetection = "feature.chordDetection"

    /// Human-readable name for a settings/debug UI.
    var title: String {
        switch self {
        case .chordDetection: return "Chord Detection (Detect tab)"
        }
    }

    /// Value used when the user hasn't explicitly overridden the flag.
    var defaultEnabled: Bool {
        switch self {
        case .chordDetection: return false   // hidden for now — work in progress
        }
    }
}

enum FeatureFlags {
    static func isEnabled(_ flag: FeatureFlag) -> Bool {
        if UserDefaults.standard.object(forKey: flag.rawValue) != nil {
            return UserDefaults.standard.bool(forKey: flag.rawValue)
        }
        return flag.defaultEnabled
    }

    static func set(_ flag: FeatureFlag, enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: flag.rawValue)
    }

    /// Restore a flag to its built-in default.
    static func reset(_ flag: FeatureFlag) {
        UserDefaults.standard.removeObject(forKey: flag.rawValue)
    }
}
