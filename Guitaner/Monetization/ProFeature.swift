import Foundation

/// Capabilities that belong to "Guitaner Pro". Free users can see them but hit a
/// paywall when they try to use them; Pro users have full access.
///
/// This is intentionally separate from `FeatureFlag` (which toggles *whether a
/// feature exists at all*). `ProFeature` answers *"is this feature paid?"*.
enum ProFeature: String, CaseIterable, Identifiable {
    case alternateTunings   = "pro.alternateTunings"
    case chordLibrary       = "pro.chordLibrary"
    case customProgressions = "pro.customProgressions"
    case practiceMode       = "pro.practiceMode"

    var id: String { rawValue }

    /// Short name shown on the paywall list.
    var title: String {
        switch self {
        case .alternateTunings:   return "All tunings"
        case .chordLibrary:       return "Full chord library"
        case .customProgressions: return "Custom progressions"
        case .practiceMode:       return "Practice mode"
        }
    }

    /// One-line benefit shown under the title on the paywall.
    var subtitle: String {
        switch self {
        case .alternateTunings:   return "Drop D, DADGAD, open tunings and custom setups"
        case .chordLibrary:       return "Every chord shape with fretboard fingerings"
        case .customProgressions: return "Build and save your own chord progressions"
        case .practiceMode:       return "Metronome, progressions and practice goals"
        }
    }

    /// SF Symbol for the paywall row.
    var systemImage: String {
        switch self {
        case .alternateTunings:   return "tuningfork"
        case .chordLibrary:       return "book"
        case .customProgressions: return "music.note.list"
        case .practiceMode:       return "metronome"
        }
    }
}
