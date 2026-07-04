import Foundation

/// A chord definition with its pitch class template.
struct ChordDefinition: Identifiable, Hashable {
    let id: String
    let name: String          // e.g. "C", "Am", "G7"
    let root: Int             // pitch class of root (0=C, 1=C#, ..., 11=B)
    let quality: ChordQuality
    let template: [Float]     // 12-element pitch class profile (normalized)

    var rootName: String {
        ChromagramAnalyzer.pitchClassNames[root]
    }

    var fullName: String { name }
}

enum ChordQuality: String, Hashable {
    case major = ""
    case minor = "m"
    case dominant7 = "7"
    case minor7 = "m7"
    case major7 = "maj7"
    case sus2 = "sus2"
    case sus4 = "sus4"
    case diminished = "dim"
    case augmented = "aug"
    case power = "5"
}

/// Database of chord templates for matching against a detected chromagram.
enum ChordDatabase {
    /// Intervals (in semitones from root) for each chord quality
    private static let qualityIntervals: [ChordQuality: [Int]] = [
        .major:      [0, 4, 7],
        .minor:      [0, 3, 7],
        .dominant7:  [0, 4, 7, 10],
        .minor7:     [0, 3, 7, 10],
        .major7:     [0, 4, 7, 11],
        .sus2:       [0, 2, 7],
        .sus4:       [0, 5, 7],
        .diminished: [0, 3, 6],
        .augmented:  [0, 4, 8],
        .power:      [0, 7],
    ]

    private static let rootNames = ChromagramAnalyzer.pitchClassNames

    /// Generate a template chromagram for a chord (root + quality).
    ///
    /// The root gets the highest weight and the perfect fifth a slightly raised
    /// one, because on a guitar the root/fifth are reinforced by the low strings'
    /// harmonics. Emphasising the root helps separate a chord from its relative
    /// minor/major, which share two of three tones (e.g. C vs. Am, C vs. Em).
    private static func makeTemplate(root: Int, quality: ChordQuality) -> [Float] {
        var template = [Float](repeating: 0, count: 12)
        guard let intervals = qualityIntervals[quality] else { return template }

        for interval in intervals {
            let pitchClass = (root + interval) % 12
            let weight: Float
            switch interval % 12 {
            case 0:  weight = 1.0   // root
            case 7:  weight = 0.9   // perfect fifth
            default: weight = 0.8   // third, seventh, extensions
            }
            template[pitchClass] = weight
        }
        return template
    }

    /// All chord definitions: every root × every quality
    static let allChords: [ChordDefinition] = {
        var chords = [ChordDefinition]()
        let qualities: [ChordQuality] = [.major, .minor, .dominant7, .minor7, .major7, .sus2, .sus4, .diminished, .augmented, .power]

        for root in 0..<12 {
            for quality in qualities {
                let name = "\(rootNames[root])\(quality.rawValue)"
                let template = makeTemplate(root: root, quality: quality)
                chords.append(ChordDefinition(
                    id: "\(root)_\(quality.rawValue)",
                    name: name,
                    root: root,
                    quality: quality,
                    template: template
                ))
            }
        }
        return chords
    }()

    /// Match a chromagram against all chord templates.
    /// Returns the best matching chord and a confidence score (0-1).
    static func match(chromagram: [Float]) -> (chord: ChordDefinition, confidence: Float)? {
        guard chromagram.count == 12 else { return nil }

        // Check if there's enough signal (at least some pitch classes active)
        let totalEnergy = chromagram.reduce(0, +)
        guard totalEnergy > 0.5 else { return nil }

        var bestChord: ChordDefinition?
        var bestScore: Float = -1

        for chord in allChords {
            let score = cosineSimilarity(chromagram, chord.template)
            if score > bestScore {
                bestScore = score
                bestChord = chord
            }
        }

        guard let chord = bestChord, bestScore > 0.4 else { return nil }

        return (chord: chord, confidence: bestScore)
    }

    /// Cosine similarity between two vectors.
    private static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<min(a.count, b.count) {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrtf(normA) * sqrtf(normB)
        guard denominator > 0 else { return 0 }
        return dotProduct / denominator
    }
}
