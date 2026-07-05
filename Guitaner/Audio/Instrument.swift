import SwiftUI
import Combine

/// A playable instrument for chord/progression preview. The raw value is the
/// General MIDI program number in the bundled GeneralUser GS SoundFont (bank 0).
enum Instrument: UInt8, CaseIterable, Identifiable {
    case steelGuitar    = 25   // Acoustic Guitar (steel) — default
    case nylonGuitar    = 24   // Acoustic Guitar (nylon)
    case jazzGuitar     = 26   // Electric Guitar (jazz)
    case cleanElectric  = 27   // Electric Guitar (clean)
    case piano          = 0    // Acoustic Grand Piano
    case electricPiano  = 4    // Electric Piano (Rhodes)

    var id: UInt8 { rawValue }

    /// GM program number to load from the SoundFont.
    var program: UInt8 { rawValue }

    var name: String {
        switch self {
        case .steelGuitar:   return "Steel Guitar"
        case .nylonGuitar:   return "Nylon Guitar"
        case .jazzGuitar:    return "Jazz Guitar"
        case .cleanElectric: return "Electric Guitar"
        case .piano:         return "Piano"
        case .electricPiano: return "Electric Piano"
        }
    }

    var systemImage: String {
        switch self {
        case .steelGuitar, .nylonGuitar, .jazzGuitar, .cleanElectric:
            return "guitars"
        case .piano, .electricPiano:
            return "pianokeys"
        }
    }
}

/// Shared, persisted selection of the chord-preview instrument. Injected at the
/// app root so the Chords and Progressions tabs stay in sync.
@MainActor
final class InstrumentStore: ObservableObject {
    @Published var selected: Instrument {
        didSet { UserDefaults.standard.set(Int(selected.program), forKey: key) }
    }

    private let key = "chord.instrument"

    init() {
        if let raw = UserDefaults.standard.object(forKey: key) as? Int,
           let instrument = Instrument(rawValue: UInt8(raw)) {
            selected = instrument
        } else {
            selected = .steelGuitar
        }
    }
}
