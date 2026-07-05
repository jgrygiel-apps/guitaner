import Foundation

/// One chord in a progression, expressed relative to the key so it can be
/// transposed to any tonic.
struct ProgressionStep: Codable, Hashable, Identifiable {
    var id = UUID()
    let semitone: Int      // offset in semitones from the key's tonic (0...11)
    let quality: String    // chord-quality suffix (matches ChordFingeringDatabase, e.g. "", "m", "7")
    let numeral: String    // display label, e.g. "I", "vi", "V7"

    /// Actual chord root pitch class for a given key tonic.
    func rootPitchClass(inKey keyRoot: Int) -> Int {
        (keyRoot + semitone) % 12
    }

    /// Concrete chord name in the given key, e.g. "Am", "G7".
    func chordName(inKey keyRoot: Int) -> String {
        ChordFingeringDatabase.rootNames[rootPitchClass(inKey: keyRoot)] + quality
    }

    /// Best default fingering for this chord in the given key.
    func fingering(inKey keyRoot: Int) -> ChordFingering? {
        ChordFingeringDatabase.fingerings(root: rootPitchClass(inKey: keyRoot), quality: quality).first
    }

    /// Frequencies of the sounded strings for this chord (standard tuning), so it
    /// can be played back. Falls back to the root note if no fingering is found.
    func frequencies(inKey keyRoot: Int) -> [Float] {
        if let freqs = fingering(inKey: keyRoot)?.frequencies, !freqs.isEmpty {
            return freqs
        }
        // Fallback: the root note in the C3–B3 octave.
        return [130.81 * powf(2, Float(rootPitchClass(inKey: keyRoot)) / 12)]
    }
}

struct Progression: Codable, Hashable, Identifiable {
    var id = UUID()
    let name: String
    let category: String
    let steps: [ProgressionStep]
    var isCustom: Bool = false

    /// Roman-numeral summary, e.g. "I – V – vi – IV".
    var numeralSummary: String {
        steps.map(\.numeral).joined(separator: " – ")
    }
}

enum ProgressionLibrary {
    /// Convenience builder for a step.
    private static func s(_ semitone: Int, _ quality: String, _ numeral: String) -> ProgressionStep {
        ProgressionStep(semitone: semitone, quality: quality, numeral: numeral)
    }

    static let all: [Progression] = [
        // MARK: Pop
        Progression(name: "Axis (I–V–vi–IV)", category: "Pop",
            steps: [s(0, "", "I"), s(7, "", "V"), s(9, "m", "vi"), s(5, "", "IV")]),
        Progression(name: "Sensitive (vi–IV–I–V)", category: "Pop",
            steps: [s(9, "m", "vi"), s(5, "", "IV"), s(0, "", "I"), s(7, "", "V")]),
        Progression(name: "Doo-Wop (I–vi–IV–V)", category: "Pop",
            steps: [s(0, "", "I"), s(9, "m", "vi"), s(5, "", "IV"), s(7, "", "V")]),
        Progression(name: "Pop Punk (I–V–vi–IV)", category: "Pop",
            steps: [s(0, "", "I"), s(7, "", "V"), s(9, "m", "vi"), s(5, "", "IV")]),
        Progression(name: "IV–I–V–vi", category: "Pop",
            steps: [s(5, "", "IV"), s(0, "", "I"), s(7, "", "V"), s(9, "m", "vi")]),
        Progression(name: "Royal Road (IV–V–iii–vi)", category: "Pop",
            steps: [s(5, "maj7", "IVmaj7"), s(7, "7", "V7"), s(4, "m7", "iii7"), s(9, "m", "vi")]),
        Progression(name: "I–iii–IV–vi", category: "Pop",
            steps: [s(0, "", "I"), s(4, "m", "iii"), s(5, "", "IV"), s(9, "m", "vi")]),
        Progression(name: "Mario Cadence (bVI–bVII–I)", category: "Pop",
            steps: [s(8, "", "bVI"), s(10, "", "bVII"), s(0, "", "I")]),
        Progression(name: "Canon Pop (I–V–vi–iii–IV)", category: "Pop",
            steps: [s(0, "", "I"), s(7, "", "V"), s(9, "m", "vi"), s(4, "m", "iii"), s(5, "", "IV")]),

        // MARK: Rock
        Progression(name: "Three-Chord (I–IV–V)", category: "Rock",
            steps: [s(0, "", "I"), s(5, "", "IV"), s(7, "", "V")]),
        Progression(name: "I–IV–V–IV", category: "Rock",
            steps: [s(0, "", "I"), s(5, "", "IV"), s(7, "", "V"), s(5, "", "IV")]),
        Progression(name: "Mixolydian (I–bVII–IV)", category: "Rock",
            steps: [s(0, "", "I"), s(10, "", "bVII"), s(5, "", "IV")]),
        Progression(name: "I–iii–IV–V", category: "Rock",
            steps: [s(0, "", "I"), s(4, "m", "iii"), s(5, "", "IV"), s(7, "", "V")]),
        Progression(name: "Aeolian Cadence (I–bVI–bVII)", category: "Rock",
            steps: [s(0, "", "I"), s(8, "", "bVI"), s(10, "", "bVII")]),
        Progression(name: "Anthem (I–bIII–bVII–IV)", category: "Rock",
            steps: [s(0, "", "I"), s(3, "", "bIII"), s(10, "", "bVII"), s(5, "", "IV")]),
        Progression(name: "I–V–IV–I", category: "Rock",
            steps: [s(0, "", "I"), s(7, "", "V"), s(5, "", "IV"), s(0, "", "I")]),
        Progression(name: "Grunge (I–bVII–bVI–bVII)", category: "Rock",
            steps: [s(0, "", "I"), s(10, "", "bVII"), s(8, "", "bVI"), s(10, "", "bVII")]),

        // MARK: Blues
        Progression(name: "12-Bar Blues", category: "Blues",
            steps: [s(0, "7", "I7"), s(0, "7", "I7"), s(0, "7", "I7"), s(0, "7", "I7"),
                    s(5, "7", "IV7"), s(5, "7", "IV7"), s(0, "7", "I7"), s(0, "7", "I7"),
                    s(7, "7", "V7"), s(5, "7", "IV7"), s(0, "7", "I7"), s(7, "7", "V7")]),
        Progression(name: "Quick-Change Blues", category: "Blues",
            steps: [s(0, "7", "I7"), s(5, "7", "IV7"), s(0, "7", "I7"), s(0, "7", "I7"),
                    s(5, "7", "IV7"), s(5, "7", "IV7"), s(0, "7", "I7"), s(0, "7", "I7"),
                    s(7, "7", "V7"), s(5, "7", "IV7"), s(0, "7", "I7"), s(7, "7", "V7")]),
        Progression(name: "8-Bar Blues (I–V–IV)", category: "Blues",
            steps: [s(0, "7", "I7"), s(7, "7", "V7"), s(5, "7", "IV7"), s(5, "7", "IV7"),
                    s(0, "7", "I7"), s(7, "7", "V7"), s(0, "7", "I7"), s(7, "7", "V7")]),
        Progression(name: "Minor 12-Bar Blues", category: "Blues",
            steps: [s(0, "m7", "i7"), s(0, "m7", "i7"), s(0, "m7", "i7"), s(0, "m7", "i7"),
                    s(5, "m7", "iv7"), s(5, "m7", "iv7"), s(0, "m7", "i7"), s(0, "m7", "i7"),
                    s(7, "7", "V7"), s(5, "m7", "iv7"), s(0, "m7", "i7"), s(7, "7", "V7")]),
        Progression(name: "Jazz Blues", category: "Blues",
            steps: [s(0, "7", "I7"), s(5, "7", "IV7"), s(0, "7", "I7"), s(0, "7", "I7"),
                    s(5, "7", "IV7"), s(5, "7", "IV7"), s(0, "7", "I7"), s(9, "7", "VI7"),
                    s(2, "m7", "ii7"), s(7, "7", "V7"), s(0, "7", "I7"), s(7, "7", "V7")]),

        // MARK: Jazz
        Progression(name: "ii–V–I", category: "Jazz",
            steps: [s(2, "m7", "ii7"), s(7, "7", "V7"), s(0, "maj7", "Imaj7")]),
        Progression(name: "Turnaround (I–VI–ii–V)", category: "Jazz",
            steps: [s(0, "maj7", "Imaj7"), s(9, "7", "VI7"), s(2, "m7", "ii7"), s(7, "7", "V7")]),
        Progression(name: "Rhythm Changes (I–vi–ii–V)", category: "Jazz",
            steps: [s(0, "maj7", "Imaj7"), s(9, "m7", "vi7"), s(2, "m7", "ii7"), s(7, "7", "V7")]),
        Progression(name: "iii–vi–ii–V", category: "Jazz",
            steps: [s(4, "m7", "iii7"), s(9, "m7", "vi7"), s(2, "m7", "ii7"), s(7, "7", "V7")]),
        Progression(name: "vi–ii–V–I", category: "Jazz",
            steps: [s(9, "m7", "vi7"), s(2, "m7", "ii7"), s(7, "7", "V7"), s(0, "maj7", "Imaj7")]),
        Progression(name: "Long ii–V–I (iii–vi–ii–V–I)", category: "Jazz",
            steps: [s(4, "m7", "iii7"), s(9, "m7", "vi7"), s(2, "m7", "ii7"), s(7, "7", "V7"), s(0, "maj7", "Imaj7")]),
        Progression(name: "Tritone Sub (ii–bII7–I)", category: "Jazz",
            steps: [s(2, "m7", "ii7"), s(1, "7", "bII7"), s(0, "maj7", "Imaj7")]),
        Progression(name: "Backdoor (ii–bVII7–I)", category: "Jazz",
            steps: [s(2, "m7", "ii7"), s(10, "7", "bVII7"), s(0, "maj7", "Imaj7")]),

        // MARK: Minor
        Progression(name: "Minor Axis (i–VI–III–VII)", category: "Minor",
            steps: [s(0, "m", "i"), s(8, "", "VI"), s(3, "", "III"), s(10, "", "VII")]),
        Progression(name: "Andalusian (i–VII–VI–V)", category: "Minor",
            steps: [s(0, "m", "i"), s(10, "", "VII"), s(8, "", "VI"), s(7, "", "V")]),
        Progression(name: "i–iv–v", category: "Minor",
            steps: [s(0, "m", "i"), s(5, "m", "iv"), s(7, "m", "v")]),
        Progression(name: "i–iv–V7", category: "Minor",
            steps: [s(0, "m", "i"), s(5, "m", "iv"), s(7, "7", "V7")]),
        Progression(name: "i–VII–VI–VII", category: "Minor",
            steps: [s(0, "m", "i"), s(10, "", "VII"), s(8, "", "VI"), s(10, "", "VII")]),
        Progression(name: "Minor ii–V–i", category: "Minor",
            steps: [s(2, "dim", "ii°"), s(7, "7", "V7"), s(0, "m", "i")]),
        Progression(name: "i–iv–VII–III", category: "Minor",
            steps: [s(0, "m", "i"), s(5, "m", "iv"), s(10, "", "VII"), s(3, "", "III")]),
        Progression(name: "i–VI–VII", category: "Minor",
            steps: [s(0, "m", "i"), s(8, "", "VI"), s(10, "", "VII")]),
        Progression(name: "i–v–VI–iv", category: "Minor",
            steps: [s(0, "m", "i"), s(7, "m", "v"), s(8, "", "VI"), s(5, "m", "iv")]),
        Progression(name: "i–III–VII–VI", category: "Minor",
            steps: [s(0, "m", "i"), s(3, "", "III"), s(10, "", "VII"), s(8, "", "VI")]),
        Progression(name: "Harmonic Minor (i–iv–V7–i)", category: "Minor",
            steps: [s(0, "m", "i"), s(5, "m", "iv"), s(7, "7", "V7"), s(0, "m", "i")]),

        // MARK: Classical
        Progression(name: "Pachelbel Canon", category: "Classical",
            steps: [s(0, "", "I"), s(7, "", "V"), s(9, "m", "vi"), s(4, "m", "iii"),
                    s(5, "", "IV"), s(0, "", "I"), s(5, "", "IV"), s(7, "", "V")]),
        Progression(name: "Circle of Fifths (vi–ii–V–I)", category: "Classical",
            steps: [s(9, "m", "vi"), s(2, "m", "ii"), s(7, "", "V"), s(0, "", "I")]),
        Progression(name: "Perfect Cadence (ii–V–I)", category: "Classical",
            steps: [s(2, "m", "ii"), s(7, "", "V"), s(0, "", "I")]),
        Progression(name: "Plagal Amen (IV–I)", category: "Classical",
            steps: [s(5, "", "IV"), s(0, "", "I")]),

        // MARK: Folk
        Progression(name: "Folk (I–IV–I–V)", category: "Folk",
            steps: [s(0, "", "I"), s(5, "", "IV"), s(0, "", "I"), s(7, "", "V")]),
        Progression(name: "50s (I–vi–IV–V)", category: "Folk",
            steps: [s(0, "", "I"), s(9, "m", "vi"), s(5, "", "IV"), s(7, "", "V")]),
        Progression(name: "I–IV–V–IV (Folk)", category: "Folk",
            steps: [s(0, "", "I"), s(5, "", "IV"), s(7, "", "V"), s(5, "", "IV")]),
        Progression(name: "Waltz (I–IV–V–I)", category: "Folk",
            steps: [s(0, "", "I"), s(5, "", "IV"), s(7, "", "V"), s(0, "", "I")]),

        // MARK: R&B / Neo-Soul
        Progression(name: "Neo-Soul (Imaj7–iii7–vi7–ii7)", category: "R&B",
            steps: [s(0, "maj7", "Imaj7"), s(4, "m7", "iii7"), s(9, "m7", "vi7"), s(2, "m7", "ii7")]),
        Progression(name: "Imaj7–vi7–ii7–V7", category: "R&B",
            steps: [s(0, "maj7", "Imaj7"), s(9, "m7", "vi7"), s(2, "m7", "ii7"), s(7, "7", "V7")]),
        Progression(name: "IVmaj7–iii7–ii7–Imaj7", category: "R&B",
            steps: [s(5, "maj7", "IVmaj7"), s(4, "m7", "iii7"), s(2, "m7", "ii7"), s(0, "maj7", "Imaj7")]),
        Progression(name: "Quiet Storm (ii7–iii7–IVmaj7)", category: "R&B",
            steps: [s(2, "m7", "ii7"), s(4, "m7", "iii7"), s(5, "maj7", "IVmaj7")]),

        // MARK: Gospel
        Progression(name: "Gospel (I–I7–IV–iv)", category: "Gospel",
            steps: [s(0, "", "I"), s(0, "7", "I7"), s(5, "", "IV"), s(5, "m", "iv")]),
        Progression(name: "I–iii–IV–iv", category: "Gospel",
            steps: [s(0, "", "I"), s(4, "m", "iii"), s(5, "", "IV"), s(5, "m", "iv")]),
        Progression(name: "6–2–5–1", category: "Gospel",
            steps: [s(9, "m7", "vi7"), s(2, "m7", "ii7"), s(7, "7", "V7"), s(0, "maj7", "Imaj7")]),
        Progression(name: "IV–iv–I (Backdoor Amen)", category: "Gospel",
            steps: [s(5, "", "IV"), s(5, "m", "iv"), s(0, "", "I")]),

        // MARK: Latin / Bossa
        Progression(name: "Bossa (Imaj7–ii7–V7)", category: "Latin",
            steps: [s(0, "maj7", "Imaj7"), s(2, "m7", "ii7"), s(7, "7", "V7")]),
        Progression(name: "Samba (ii7–V7–iii7–VI7)", category: "Latin",
            steps: [s(2, "m7", "ii7"), s(7, "7", "V7"), s(4, "m7", "iii7"), s(9, "7", "VI7")]),
        Progression(name: "Montuno (i–iv–V7)", category: "Latin",
            steps: [s(0, "m", "i"), s(5, "m", "iv"), s(7, "7", "V7")]),
        Progression(name: "Spanish Phrygian (i–bII–i)", category: "Latin",
            steps: [s(0, "m", "i"), s(1, "", "bII"), s(0, "m", "i")]),

        // MARK: Country
        Progression(name: "Country (I–V–IV–V)", category: "Country",
            steps: [s(0, "", "I"), s(7, "", "V"), s(5, "", "IV"), s(7, "", "V")]),
        Progression(name: "Train Beat (I–IV–V)", category: "Country",
            steps: [s(0, "", "I"), s(5, "", "IV"), s(7, "", "V")]),
        Progression(name: "Honky-Tonk (I–I–IV–V)", category: "Country",
            steps: [s(0, "", "I"), s(0, "", "I"), s(5, "", "IV"), s(7, "", "V")]),
        Progression(name: "Nashville (I–IV–vi–V)", category: "Country",
            steps: [s(0, "", "I"), s(5, "", "IV"), s(9, "m", "vi"), s(7, "", "V")]),
    ]

    /// Categories in a stable display order.
    static let categoryOrder = ["Pop", "Rock", "Blues", "Jazz", "Minor", "Classical", "Folk", "R&B", "Gospel", "Latin", "Country"]

    static func categories(including custom: [Progression]) -> [String] {
        var cats = categoryOrder.filter { cat in all.contains { $0.category == cat } }
        if !custom.isEmpty { cats.insert("My Progressions", at: 0) }
        return cats
    }

    /// Degree palette for the custom builder (major + minor + common sevenths).
    static let builderDegrees: [ProgressionStep] = [
        s(0, "", "I"),   s(2, "m", "ii"),  s(4, "m", "iii"), s(5, "", "IV"),
        s(7, "", "V"),   s(7, "7", "V7"),  s(9, "m", "vi"),  s(11, "dim", "vii°"),
        s(0, "m", "i"),  s(3, "", "III"),  s(5, "m", "iv"),  s(7, "m", "v"),
        s(8, "", "VI"),  s(10, "", "VII"), s(0, "maj7", "Imaj7"), s(0, "7", "I7"),
    ]
}
