import Foundation

struct TuningDefinition: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let strings: [MusicalNote]  // ordered from lowest to highest pitched string
}

extension TuningDefinition {
    static let standard = TuningDefinition(
        id: "standard",
        name: "Standard",
        strings: [.e2, .a2, .d3, .g3, .b3, .e4]
    )

    static let dropD = TuningDefinition(
        id: "dropD",
        name: "Drop D",
        strings: [.d2, .a2, .d3, .g3, .b3, .e4]
    )

    static let halfStepDown = TuningDefinition(
        id: "halfStepDown",
        name: "Half Step Down",
        strings: [
            MusicalNote(id: 39, name: "D#", octave: 2, frequency: NoteDatabase.frequency(forMIDI: 39)),
            MusicalNote(id: 44, name: "G#", octave: 2, frequency: NoteDatabase.frequency(forMIDI: 44)),
            MusicalNote(id: 49, name: "C#", octave: 3, frequency: NoteDatabase.frequency(forMIDI: 49)),
            .gb3, .bb3, .eb4
        ]
    )

    static let openG = TuningDefinition(
        id: "openG",
        name: "Open G",
        strings: [.d2, .g3, .d3, .g3, .b3, .d4]
    )

    static let dadgad = TuningDefinition(
        id: "dadgad",
        name: "DADGAD",
        strings: [.d2, .a2, .d3, .g3, .a3, .d4]
    )

    static let openD = TuningDefinition(
        id: "openD",
        name: "Open D",
        strings: [.d2, .a2, .d3, .gb3, .a3, .d4]
    )

    static let allTunings: [TuningDefinition] = [
        .standard, .dropD, .halfStepDown, .openG, .openD, .dadgad
    ]
}
