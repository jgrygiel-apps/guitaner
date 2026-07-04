import Foundation

/// Pitch tracker with note locking, harmonic rejection, and smooth tracking.
///
/// Once a pitch is established ("locked"), it rejects harmonic/octave errors
/// and only switches to a new note after multiple consecutive confirmations.
/// This eliminates display flickering and jumping between harmonics.
final class PitchSmoother {
    // Tracking state
    private var lockedFrequency: Float = 0
    private var emaFrequency: Float = 0

    // Candidate tracking for note switching
    private var candidateFrequency: Float = 0
    private var candidateConfirmations: Int = 0
    private let confirmationsNeeded: Int = 4  // frames needed to confirm new note

    // Parameters
    private let emaAlpha: Float             // how fast to track within a locked note
    private let closeThresholdCents: Float  // max deviation to consider "same note"
    private let resetThresholdCents: Float  // deviation that triggers candidate tracking

    init(
        emaAlpha: Float = AudioConstants.smootherEMAAlpha,
        resetThresholdCents: Float = AudioConstants.smootherResetThresholdCents
    ) {
        self.emaAlpha = emaAlpha
        self.closeThresholdCents = 80.0   // within ~a minor third = same note region
        self.resetThresholdCents = resetThresholdCents
    }

    /// Process a raw detected frequency and return a stable, smoothed frequency.
    /// Returns the locked/tracked frequency, or 0 if no note is established yet.
    func smooth(_ frequency: Float) -> Float {
        guard frequency > 0 else {
            return lockedFrequency  // keep returning last locked value on missed frames
        }

        // No lock yet — establish one
        if lockedFrequency == 0 {
            return tryEstablishLock(frequency)
        }

        // Check if this is a harmonic/octave error of the locked pitch
        if isHarmonicOf(frequency, reference: lockedFrequency) {
            // Reject harmonic — return locked frequency unchanged
            return lockedFrequency
        }

        // Check if close to current lock
        let centsFromLock = centsBetween(frequency, lockedFrequency)

        if centsFromLock < closeThresholdCents {
            // Close to lock — update with EMA
            emaFrequency = emaAlpha * frequency + (1.0 - emaAlpha) * emaFrequency
            lockedFrequency = emaFrequency
            candidateConfirmations = 0  // reset any candidate
            return lockedFrequency
        }

        // Far from lock — this might be a new note. Track as candidate.
        return trackCandidate(frequency)
    }

    /// The last stable frequency (for display hold during silence).
    var lastFrequency: Float { lockedFrequency }

    /// Whether a note is currently locked.
    var isLocked: Bool { lockedFrequency > 0 }

    /// Reset all state.
    func reset() {
        lockedFrequency = 0
        emaFrequency = 0
        candidateFrequency = 0
        candidateConfirmations = 0
    }

    // MARK: - Private

    /// Try to establish an initial lock from scratch.
    private func tryEstablishLock(_ frequency: Float) -> Float {
        if candidateFrequency == 0 {
            candidateFrequency = frequency
            candidateConfirmations = 1
            return 0
        }

        let centsFromCandidate = centsBetween(frequency, candidateFrequency)

        if centsFromCandidate < closeThresholdCents || isHarmonicOf(frequency, reference: candidateFrequency) {
            // Consistent with candidate (or harmonic of it — use the candidate's octave)
            candidateConfirmations += 1

            // Use the non-harmonic frequency for averaging
            let freq = isHarmonicOf(frequency, reference: candidateFrequency) ? candidateFrequency : frequency
            candidateFrequency = 0.5 * freq + 0.5 * candidateFrequency

            if candidateConfirmations >= confirmationsNeeded {
                lockedFrequency = candidateFrequency
                emaFrequency = candidateFrequency
                return lockedFrequency
            }
            return 0  // not confirmed yet
        } else {
            // Different note — restart candidate
            candidateFrequency = frequency
            candidateConfirmations = 1
            return 0
        }
    }

    /// Track a candidate for note switching while maintaining current lock.
    private func trackCandidate(_ frequency: Float) -> Float {
        if candidateFrequency == 0 || centsBetween(frequency, candidateFrequency) > closeThresholdCents {
            // New candidate
            candidateFrequency = frequency
            candidateConfirmations = 1
        } else {
            // Consistent with existing candidate
            candidateConfirmations += 1
            candidateFrequency = 0.5 * frequency + 0.5 * candidateFrequency

            if candidateConfirmations >= confirmationsNeeded {
                // Switch lock to new note
                lockedFrequency = candidateFrequency
                emaFrequency = candidateFrequency
                candidateFrequency = 0
                candidateConfirmations = 0
                return lockedFrequency
            }
        }

        // Keep showing old locked note until new one is confirmed
        return lockedFrequency
    }

    /// Check if `freq` is a harmonic or subharmonic of `reference`.
    /// Checks ratios: 2:1, 3:1, 1:2, 1:3, 3:2, 2:3
    private func isHarmonicOf(_ freq: Float, reference: Float) -> Bool {
        guard reference > 0 else { return false }
        let ratio = freq / reference
        let harmonicRatios: [Float] = [0.333, 0.5, 2.0, 3.0, 1.5, 0.667]
        let toleranceCents: Float = 30.0

        for target in harmonicRatios {
            let centsOff = abs(1200.0 * log2(ratio / target))
            if centsOff < toleranceCents {
                return true
            }
        }
        return false
    }

    /// Absolute cents distance between two frequencies.
    private func centsBetween(_ f1: Float, _ f2: Float) -> Float {
        guard f1 > 0, f2 > 0 else { return Float.infinity }
        return abs(1200.0 * log2(f1 / f2))
    }
}
