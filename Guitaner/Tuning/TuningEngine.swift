import Foundation

struct TuningResult: Sendable {
    let detectedFrequency: Float
    let nearestNote: MusicalNote
    let centsDeviation: Float       // negative = flat, positive = sharp
    let matchedStringIndex: Int?    // index in current tuning, nil if no close match
    let confidence: Float
    let isInTune: Bool
}

final class TuningEngine {
    var currentTuning: TuningDefinition = .standard

    /// Analyze a detected frequency against the current tuning.
    func analyze(frequency: Float, confidence: Float) -> TuningResult {
        // Find nearest note globally (chromatic)
        let nearestNote = NoteDatabase.nearestNote(to: frequency)
        let cents = NoteDatabase.centsDeviation(from: frequency, to: nearestNote.frequency)

        // Try to match to a specific string in the current tuning
        let matchedStringIndex = findClosestString(to: frequency)

        let isInTune = abs(cents) <= AudioConstants.inTuneToleranceCents

        return TuningResult(
            detectedFrequency: frequency,
            nearestNote: nearestNote,
            centsDeviation: cents,
            matchedStringIndex: matchedStringIndex,
            confidence: confidence,
            isInTune: isInTune
        )
    }

    /// Find the closest string in the current tuning within a reasonable range (±300 cents).
    private func findClosestString(to frequency: Float) -> Int? {
        var bestIndex: Int?
        var bestCents: Float = .infinity

        for (index, stringNote) in currentTuning.strings.enumerated() {
            let cents = abs(NoteDatabase.centsDeviation(from: frequency, to: stringNote.frequency))
            if cents < bestCents && cents <= 300.0 {
                bestCents = cents
                bestIndex = index
            }
        }

        return bestIndex
    }
}
