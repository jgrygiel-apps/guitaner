import Foundation

/// A single chord voicing on a 6-string guitar.
struct ChordFingering: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let strings: [Int]           // 6 values: -1=muted, 0=open, 1+=fret number (low E to high E)
    let baseFret: Int
    let barreString: Int?        // nil = no barre
    let fingers: [Int]           // 6 values: 0=none, 1-4=finger number

    var maxFret: Int {
        strings.filter { $0 > 0 }.max() ?? 0
    }

    /// Frequencies of the sounded strings (standard tuning: E2 A2 D3 G3 B3 E4),
    /// used to play the voicing back.
    var frequencies: [Float] {
        let openFreqs: [Float] = [82.41, 110.0, 146.83, 196.0, 246.94, 329.63]
        return strings.enumerated().compactMap { index, fret in
            fret < 0 ? nil : openFreqs[index] * powf(2, Float(fret) / 12)
        }
    }
}

/// Database of guitar chord fingerings using the CAGED system.
/// Generates all 5 barre shapes (C, A, G, E, D) for every root + quality,
/// plus hand-crafted open voicings for common chords.
enum ChordFingeringDatabase {
    static let rootNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    static let qualities: [(name: String, suffix: String)] = [
        ("Major", ""),
        ("Minor", "m"),
        ("7", "7"),
        ("Minor 7", "m7"),
        ("Major 7", "maj7"),
        ("Sus2", "sus2"),
        ("Sus4", "sus4"),
        ("Dim", "dim"),
        ("Dim 7", "dim7"),
        ("Minor 7♭5", "m7b5"),
        ("Aug", "aug"),
        ("6", "6"),
        ("Minor 6", "m6"),
        ("Add9", "add9"),
        ("9", "9"),
        ("Minor 9", "m9"),
        ("Major 9", "maj9"),
        ("11", "11"),
        ("Minor 11", "m11"),
        ("13", "13"),
        ("7♭9", "7b9"),
        ("7♯9", "7#9"),
    ]

    /// Get all fingering variants for a given root + quality.
    static func fingerings(root: Int, quality: String) -> [ChordFingering] {
        var results = [ChordFingering]()

        // Add hand-crafted open shapes first
        let key = "\(root)_\(quality)"
        if let open = openShapes[key] {
            results.append(contentsOf: open)
        }

        // Generate all CAGED barre shapes
        results.append(contentsOf: cagedFingerings(root: root, quality: quality))

        // Deduplicate (if open shape matches a generated barre shape)
        return dedup(results)
    }

    // MARK: - CAGED System Barre Shapes

    /// Each CAGED shape is defined as intervals relative to fret 0.
    /// When transposed, fret 0 becomes the barre fret.
    private struct BarreTemplate {
        let shapeName: String
        let rootStringIndex: Int     // which string has the root note (0=lowE, 1=A, etc.)
        let openRootFret: Int        // the root note's fret in the open shape (for offset calculation)
        let intervals: [Int]         // fret positions relative to barre (-1 = muted)
        let fingerPattern: [Int]
    }

    private static func cagedFingerings(root: Int, quality: String) -> [ChordFingering] {
        guard let templates = cagedTemplates[quality] else {
            // Fall back to major templates for unknown qualities
            return cagedTemplates[""].map { generateFromTemplates(root: root, templates: $0) } ?? []
        }
        return generateFromTemplates(root: root, templates: templates)
    }

    private static func generateFromTemplates(root: Int, templates: [BarreTemplate]) -> [ChordFingering] {
        var results = [ChordFingering]()

        for tmpl in templates {
            // Calculate which fret the barre sits on
            // The root note on the template's root string in the open position
            let openRootPitch = openStringPitches[tmpl.rootStringIndex] + tmpl.openRootFret
            let targetPitch = root
            var barreFret = (targetPitch - openRootPitch % 12 + 12) % 12
            if barreFret == 0 { barreFret = 12 }

            // Skip if barre would be too high
            guard barreFret <= 12 else { continue }

            // Transpose intervals
            let transposed = tmpl.intervals.map { $0 < 0 ? -1 : $0 + barreFret }

            // Skip if any fret is unreachably high
            let maxFret = transposed.filter { $0 > 0 }.max() ?? 0
            guard maxFret <= 17 else { continue }

            // Skip open-position duplicates (barreFret would be 0 effectively)
            // These are covered by hand-crafted open shapes

            let name = "\(tmpl.shapeName)-shape (\(ordinal(barreFret)) fret)"

            results.append(ChordFingering(
                name: name,
                strings: transposed,
                baseFret: barreFret,
                barreString: barreFret,
                fingers: tmpl.fingerPattern
            ))
        }

        return results
    }

    // Open string pitch classes: E=4, A=9, D=2, G=7, B=11, E=4
    private static let openStringPitches = [4, 9, 2, 7, 11, 4]

    // CAGED templates for each quality
    // intervals are relative: 0 = barre fret, 1 = barre+1, etc., -1 = muted
    private static let cagedTemplates: [String: [BarreTemplate]] = [
        // Major
        "": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 2, 2, 1, 0, 0], fingerPattern: [1, 3, 4, 2, 1, 1]),
            BarreTemplate(shapeName: "A", rootStringIndex: 1, openRootFret: 0,
                          intervals: [-1, 0, 2, 2, 2, 0], fingerPattern: [0, 1, 3, 4, 2, 1]),
            BarreTemplate(shapeName: "D", rootStringIndex: 2, openRootFret: 0,  // root on D string open
                          intervals: [-1, -1, 0, 2, 3, 2], fingerPattern: [0, 0, 1, 2, 4, 3]),
            BarreTemplate(shapeName: "C", rootStringIndex: 1, openRootFret: 3,
                          intervals: [-1, 3, 2, 0, 1, 0], fingerPattern: [0, 4, 3, 0, 2, 1]),
        ],
        // Minor
        "m": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 2, 2, 0, 0, 0], fingerPattern: [1, 3, 4, 1, 1, 1]),
            BarreTemplate(shapeName: "A", rootStringIndex: 1, openRootFret: 0,
                          intervals: [-1, 0, 2, 2, 1, 0], fingerPattern: [0, 1, 3, 4, 2, 1]),
            BarreTemplate(shapeName: "D", rootStringIndex: 2, openRootFret: 0,
                          intervals: [-1, -1, 0, 2, 3, 1], fingerPattern: [0, 0, 1, 3, 4, 2]),
        ],
        // Dominant 7
        "7": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 2, 0, 1, 0, 0], fingerPattern: [1, 3, 1, 2, 1, 1]),
            BarreTemplate(shapeName: "A", rootStringIndex: 1, openRootFret: 0,
                          intervals: [-1, 0, 2, 0, 2, 0], fingerPattern: [0, 1, 3, 1, 4, 1]),
            BarreTemplate(shapeName: "D", rootStringIndex: 2, openRootFret: 0,
                          intervals: [-1, -1, 0, 2, 1, 2], fingerPattern: [0, 0, 1, 3, 2, 4]),
        ],
        // Minor 7
        "m7": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 2, 0, 0, 0, 0], fingerPattern: [1, 3, 1, 1, 1, 1]),
            BarreTemplate(shapeName: "A", rootStringIndex: 1, openRootFret: 0,
                          intervals: [-1, 0, 2, 0, 1, 0], fingerPattern: [0, 1, 3, 1, 2, 1]),
        ],
        // Major 7
        "maj7": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 2, 1, 1, 0, 0], fingerPattern: [1, 4, 2, 3, 1, 1]),
            BarreTemplate(shapeName: "A", rootStringIndex: 1, openRootFret: 0,
                          intervals: [-1, 0, 2, 1, 2, 0], fingerPattern: [0, 1, 3, 2, 4, 1]),
        ],
        // Sus2 — only the A-shape is a valid movable sus2 (root, 2, 5).
        // The E-shape barre with this fingering actually produces a sus4, so it's omitted.
        "sus2": [
            BarreTemplate(shapeName: "A", rootStringIndex: 1, openRootFret: 0,
                          intervals: [-1, 0, 2, 2, 0, 0], fingerPattern: [0, 1, 3, 4, 1, 1]),
        ],
        // Sus4
        "sus4": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 2, 2, 2, 0, 0], fingerPattern: [1, 2, 3, 4, 1, 1]),
            BarreTemplate(shapeName: "A", rootStringIndex: 1, openRootFret: 0,
                          intervals: [-1, 0, 2, 2, 3, 0], fingerPattern: [0, 1, 2, 3, 4, 1]),
        ],
        // Diminished
        "dim": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 1, 2, 0, -1, -1], fingerPattern: [1, 2, 3, 1, 0, 0]),
            BarreTemplate(shapeName: "A", rootStringIndex: 1, openRootFret: 0,
                          intervals: [-1, 0, 1, 2, 1, -1], fingerPattern: [0, 1, 2, 4, 3, 0]),
        ],
        // Augmented
        "aug": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 3, 2, 1, 1, 0], fingerPattern: [1, 4, 3, 2, 1, 1]),
            BarreTemplate(shapeName: "A", rootStringIndex: 1, openRootFret: 0,
                          intervals: [-1, 0, 3, 2, 2, 1], fingerPattern: [0, 1, 4, 3, 2, 1]),
        ],
        // Add9 — E-shape only (root, 3, 5, 9). The previous A-shape [-1,0,2,2,2,2]
        // actually voiced a 6 chord (major 6th on top, no 9), so it's omitted.
        "add9": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 2, 2, 1, 0, 2], fingerPattern: [1, 3, 4, 2, 1, 1]),
        ],
        // 6th
        "6": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 2, 2, 1, 2, 0], fingerPattern: [1, 3, 4, 1, 2, 1]),
            BarreTemplate(shapeName: "A", rootStringIndex: 1, openRootFret: 0,
                          intervals: [-1, 0, 2, 2, 2, 2], fingerPattern: [0, 1, 2, 3, 3, 4]),
        ],
        // 9th — E-shape only (root, 3, 5, b7, 9). The previous A-shape voiced a
        // maj7 + 6 instead of b7 + 9, so it's omitted (a correct movable 9 A-shape
        // needs a note below the barre, which this template system can't express).
        "9": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 2, 0, 1, 0, 2], fingerPattern: [1, 3, 1, 2, 1, 4]),
        ],
        // Half-diminished (m7♭5): root, ♭3, ♭5, ♭7. E-shape on the low 4 strings,
        // A-shape on strings A–B.
        "m7b5": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 1, 0, 0, -1, -1], fingerPattern: [1, 2, 1, 1, 0, 0]),
            BarreTemplate(shapeName: "A", rootStringIndex: 1, openRootFret: 0,
                          intervals: [-1, 0, 1, 0, 1, -1], fingerPattern: [0, 1, 2, 1, 3, 0]),
        ],
        // Diminished 7 (root, ♭3, ♭5, 𝄫7). Top-4-string voicing, root on D string.
        "dim7": [
            BarreTemplate(shapeName: "D", rootStringIndex: 2, openRootFret: 0,
                          intervals: [-1, -1, 0, 1, 0, 1], fingerPattern: [0, 0, 1, 2, 1, 3]),
        ],
        // Minor 6 (root, ♭3, 5, 6) — E-shape.
        "m6": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 2, 2, 0, 2, 0], fingerPattern: [1, 3, 4, 1, 2, 1]),
        ],
        // Minor 9 (root, ♭3, 5, ♭7, 9) — E-shape.
        "m9": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 2, 0, 0, 0, 2], fingerPattern: [1, 3, 1, 1, 1, 4]),
        ],
        // Major 9 (root, 3, 5, maj7, 9) — E-shape.
        "maj9": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 2, 1, 1, 0, 2], fingerPattern: [1, 3, 2, 2, 1, 4]),
        ],
        // Dominant 11 (root, 9, 11, 5, ♭7 — 3rd omitted) — E-shape.
        "11": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 2, 0, 2, 0, 2], fingerPattern: [1, 2, 1, 3, 1, 4]),
        ],
        // Minor 11 (root, 9, ♭3, 11, 5, ♭7) — full barre with a 9 on top.
        "m11": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, 0, 0, 0, 0, 2], fingerPattern: [1, 1, 1, 1, 1, 3]),
        ],
        // Dominant 13 (root, 3, ♭7, 13) — jazz shell voicing, root on low E.
        "13": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, -1, 0, 1, 2, -1], fingerPattern: [1, 0, 1, 2, 3, 0]),
        ],
        // Dominant 7♭9 (root, ♭9, 3, 5, ♭7) — E-shape.
        "7b9": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, -1, 0, 1, 0, 1], fingerPattern: [1, 0, 1, 2, 1, 3]),
        ],
        // Dominant 7♯9 ("Hendrix", root, 3, 5, ♭7, ♯9) — E-shape.
        "7#9": [
            BarreTemplate(shapeName: "E", rootStringIndex: 0, openRootFret: 0,
                          intervals: [0, -1, 0, 1, 0, 3], fingerPattern: [1, 0, 1, 2, 1, 4]),
        ],
    ]

    // MARK: - Hand-crafted Open Shapes

    private static let openShapes: [String: [ChordFingering]] = [
        // C
        "0_": [
            ChordFingering(name: "Open", strings: [-1, 3, 2, 0, 1, 0], baseFret: 1, barreString: nil, fingers: [0, 3, 2, 0, 1, 0]),
        ],
        "0_m": [
            ChordFingering(name: "Barre (3rd)", strings: [-1, 3, 5, 5, 4, 3], baseFret: 3, barreString: 3, fingers: [0, 1, 3, 4, 2, 1]),
        ],
        "0_7": [
            ChordFingering(name: "Open", strings: [-1, 3, 2, 3, 1, 0], baseFret: 1, barreString: nil, fingers: [0, 3, 2, 4, 1, 0]),
        ],
        "0_maj7": [
            ChordFingering(name: "Open", strings: [-1, 3, 2, 0, 0, 0], baseFret: 1, barreString: nil, fingers: [0, 3, 2, 0, 0, 0]),
        ],
        // D
        "2_": [
            ChordFingering(name: "Open", strings: [-1, -1, 0, 2, 3, 2], baseFret: 1, barreString: nil, fingers: [0, 0, 0, 1, 3, 2]),
        ],
        "2_m": [
            ChordFingering(name: "Open", strings: [-1, -1, 0, 2, 3, 1], baseFret: 1, barreString: nil, fingers: [0, 0, 0, 2, 3, 1]),
        ],
        "2_7": [
            ChordFingering(name: "Open", strings: [-1, -1, 0, 2, 1, 2], baseFret: 1, barreString: nil, fingers: [0, 0, 0, 2, 1, 3]),
        ],
        "2_sus2": [
            ChordFingering(name: "Open", strings: [-1, -1, 0, 2, 3, 0], baseFret: 1, barreString: nil, fingers: [0, 0, 0, 1, 3, 0]),
        ],
        "2_sus4": [
            ChordFingering(name: "Open", strings: [-1, -1, 0, 2, 3, 3], baseFret: 1, barreString: nil, fingers: [0, 0, 0, 1, 2, 3]),
        ],
        // E
        "4_": [
            ChordFingering(name: "Open", strings: [0, 2, 2, 1, 0, 0], baseFret: 1, barreString: nil, fingers: [0, 2, 3, 1, 0, 0]),
        ],
        "4_m": [
            ChordFingering(name: "Open", strings: [0, 2, 2, 0, 0, 0], baseFret: 1, barreString: nil, fingers: [0, 2, 3, 0, 0, 0]),
        ],
        "4_7": [
            ChordFingering(name: "Open", strings: [0, 2, 0, 1, 0, 0], baseFret: 1, barreString: nil, fingers: [0, 2, 0, 1, 0, 0]),
        ],
        "4_m7": [
            ChordFingering(name: "Open", strings: [0, 2, 0, 0, 0, 0], baseFret: 1, barreString: nil, fingers: [0, 2, 0, 0, 0, 0]),
        ],
        "4_sus4": [
            ChordFingering(name: "Open", strings: [0, 2, 2, 2, 0, 0], baseFret: 1, barreString: nil, fingers: [0, 2, 3, 4, 0, 0]),
        ],
        // F
        "5_": [
            ChordFingering(name: "Small barre", strings: [-1, -1, 3, 2, 1, 1], baseFret: 1, barreString: 1, fingers: [0, 0, 3, 2, 1, 1]),
        ],
        // G
        "7_": [
            ChordFingering(name: "Open", strings: [3, 2, 0, 0, 0, 3], baseFret: 1, barreString: nil, fingers: [2, 1, 0, 0, 0, 3]),
        ],
        "7_7": [
            ChordFingering(name: "Open", strings: [3, 2, 0, 0, 0, 1], baseFret: 1, barreString: nil, fingers: [3, 2, 0, 0, 0, 1]),
        ],
        "7_m7": [
            ChordFingering(name: "Barre (3rd)", strings: [3, 5, 3, 3, 3, 3], baseFret: 3, barreString: 3, fingers: [1, 3, 1, 1, 1, 1]),
        ],
        // A
        "9_": [
            ChordFingering(name: "Open", strings: [-1, 0, 2, 2, 2, 0], baseFret: 1, barreString: nil, fingers: [0, 0, 1, 2, 3, 0]),
        ],
        "9_m": [
            ChordFingering(name: "Open", strings: [-1, 0, 2, 2, 1, 0], baseFret: 1, barreString: nil, fingers: [0, 0, 2, 3, 1, 0]),
        ],
        "9_7": [
            ChordFingering(name: "Open", strings: [-1, 0, 2, 0, 2, 0], baseFret: 1, barreString: nil, fingers: [0, 0, 1, 0, 2, 0]),
        ],
        "9_m7": [
            ChordFingering(name: "Open", strings: [-1, 0, 2, 0, 1, 0], baseFret: 1, barreString: nil, fingers: [0, 0, 2, 0, 1, 0]),
        ],
        "9_maj7": [
            ChordFingering(name: "Open", strings: [-1, 0, 2, 1, 2, 0], baseFret: 1, barreString: nil, fingers: [0, 0, 2, 1, 3, 0]),
        ],
        "9_sus2": [
            ChordFingering(name: "Open", strings: [-1, 0, 2, 2, 0, 0], baseFret: 1, barreString: nil, fingers: [0, 0, 1, 2, 0, 0]),
        ],
        "9_sus4": [
            ChordFingering(name: "Open", strings: [-1, 0, 2, 2, 3, 0], baseFret: 1, barreString: nil, fingers: [0, 0, 1, 2, 3, 0]),
        ],
        // B
        "11_": [
            ChordFingering(name: "A-shape (2nd)", strings: [-1, 2, 4, 4, 4, 2], baseFret: 2, barreString: 2, fingers: [0, 1, 2, 3, 4, 1]),
        ],
        "11_m": [
            ChordFingering(name: "A-shape (2nd)", strings: [-1, 2, 4, 4, 3, 2], baseFret: 2, barreString: 2, fingers: [0, 1, 3, 4, 2, 1]),
        ],
        "11_7": [
            ChordFingering(name: "Open", strings: [-1, 2, 1, 2, 0, 2], baseFret: 1, barreString: nil, fingers: [0, 2, 1, 3, 0, 4]),
        ],
    ]

    // MARK: - Helpers

    private static func dedup(_ fingerings: [ChordFingering]) -> [ChordFingering] {
        var seen = Set<[Int]>()
        return fingerings.filter { seen.insert($0.strings).inserted }
    }

    private static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }
}
