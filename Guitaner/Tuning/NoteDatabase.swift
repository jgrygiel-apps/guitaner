import Foundation

struct MusicalNote: Hashable, Identifiable, Sendable {
    let id: Int          // MIDI note number
    let name: String     // e.g. "C", "C#", "D"
    let octave: Int
    let frequency: Float // in Hz (12-TET, A4 = 440)

    var fullName: String { "\(name)\(octave)" }
}

enum NoteDatabase {
    private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// Compute frequency for a MIDI note number using 12-TET: f = 440 * 2^((n - 69) / 12)
    static func frequency(forMIDI midi: Int) -> Float {
        440.0 * powf(2.0, Float(midi - 69) / 12.0)
    }

    /// All notes from C1 (MIDI 24) to B6 (MIDI 95).
    /// Covers the full range of guitar + bass guitar frequencies.
    static let allNotes: [MusicalNote] = {
        (24...95).map { midi in
            let name = noteNames[midi % 12]
            let octave = (midi / 12) - 1
            return MusicalNote(
                id: midi,
                name: name,
                octave: octave,
                frequency: frequency(forMIDI: midi)
            )
        }
    }()

    /// Find the nearest note to a given frequency using binary search on log-frequency.
    static func nearestNote(to frequency: Float) -> MusicalNote {
        guard frequency > 0 else { return allNotes[0] }

        var bestNote = allNotes[0]
        var bestDistance: Float = .infinity

        // Use cent distance for comparison (logarithmic, perceptually uniform)
        for note in allNotes {
            let centDistance = abs(1200.0 * log2(frequency / note.frequency))
            if centDistance < bestDistance {
                bestDistance = centDistance
                bestNote = note
            }
        }

        return bestNote
    }

    /// Cents deviation from a reference frequency: 1200 * log2(f / fRef)
    static func centsDeviation(from frequency: Float, to reference: Float) -> Float {
        guard frequency > 0, reference > 0 else { return 0 }
        return 1200.0 * log2(frequency / reference)
    }

    // Convenience note lookups by MIDI number
    static func note(midi: Int) -> MusicalNote? {
        allNotes.first { $0.id == midi }
    }
}

// MARK: - Well-known notes for tuning definitions

extension MusicalNote {
    static let c2  = MusicalNote(id: 36, name: "C",  octave: 2, frequency: NoteDatabase.frequency(forMIDI: 36))
    static let d2  = MusicalNote(id: 38, name: "D",  octave: 2, frequency: NoteDatabase.frequency(forMIDI: 38))
    static let e2  = MusicalNote(id: 40, name: "E",  octave: 2, frequency: NoteDatabase.frequency(forMIDI: 40))
    static let a2  = MusicalNote(id: 45, name: "A",  octave: 2, frequency: NoteDatabase.frequency(forMIDI: 45))
    static let b2  = MusicalNote(id: 47, name: "B",  octave: 2, frequency: NoteDatabase.frequency(forMIDI: 47))
    static let d3  = MusicalNote(id: 50, name: "D",  octave: 3, frequency: NoteDatabase.frequency(forMIDI: 50))
    static let eb3 = MusicalNote(id: 51, name: "D#", octave: 3, frequency: NoteDatabase.frequency(forMIDI: 51))
    static let e3  = MusicalNote(id: 52, name: "E",  octave: 3, frequency: NoteDatabase.frequency(forMIDI: 52))
    static let f3  = MusicalNote(id: 53, name: "F",  octave: 3, frequency: NoteDatabase.frequency(forMIDI: 53))
    static let g3  = MusicalNote(id: 55, name: "G",  octave: 3, frequency: NoteDatabase.frequency(forMIDI: 55))
    static let gb3 = MusicalNote(id: 54, name: "F#", octave: 3, frequency: NoteDatabase.frequency(forMIDI: 54))
    static let ab3 = MusicalNote(id: 56, name: "G#", octave: 3, frequency: NoteDatabase.frequency(forMIDI: 56))
    static let a3  = MusicalNote(id: 57, name: "A",  octave: 3, frequency: NoteDatabase.frequency(forMIDI: 57))
    static let bb3 = MusicalNote(id: 58, name: "A#", octave: 3, frequency: NoteDatabase.frequency(forMIDI: 58))
    static let b3  = MusicalNote(id: 59, name: "B",  octave: 3, frequency: NoteDatabase.frequency(forMIDI: 59))
    static let c4  = MusicalNote(id: 60, name: "C",  octave: 4, frequency: NoteDatabase.frequency(forMIDI: 60))
    static let db4 = MusicalNote(id: 61, name: "C#", octave: 4, frequency: NoteDatabase.frequency(forMIDI: 61))
    static let d4  = MusicalNote(id: 62, name: "D",  octave: 4, frequency: NoteDatabase.frequency(forMIDI: 62))
    static let eb4 = MusicalNote(id: 63, name: "D#", octave: 4, frequency: NoteDatabase.frequency(forMIDI: 63))
    static let e4  = MusicalNote(id: 64, name: "E",  octave: 4, frequency: NoteDatabase.frequency(forMIDI: 64))
}
