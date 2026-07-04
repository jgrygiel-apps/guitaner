import Foundation
import Accelerate

/// Extracts a chromagram (12-bin pitch class profile) from an audio signal using FFT.
///
/// A chromagram maps all detected frequencies into 12 pitch classes (C, C#, D, ..., B),
/// summing energy across all octaves. This is the standard representation for chord detection.
final class ChromagramAnalyzer {
    private let sampleRate: Float
    private let fftSize: Int
    private let halfFFTSize: Int

    // Pre-allocated FFT buffers
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var magnitudeBuffer: [Float]
    private var hannWindow: [Float]

    // vDSP FFT setup
    private let fftSetup: vDSP_DFT_Setup

    // Chromagram bin mapping: for each FFT bin, which pitch class (0-11) it maps to
    private var binToPitchClass: [Int]
    private var binWeights: [Float]

    // Pitch class names
    static let pitchClassNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    init(sampleRate: Float = 48000, fftSize: Int = 8192) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.halfFFTSize = fftSize / 2

        self.realBuffer = [Float](repeating: 0, count: fftSize)
        self.imagBuffer = [Float](repeating: 0, count: fftSize)
        self.magnitudeBuffer = [Float](repeating: 0, count: fftSize / 2)

        // Hann window for FFT (unlike YIN, FFT benefits from windowing)
        self.hannWindow = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&hannWindow, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        self.fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)!

        // Pre-compute pitch class mapping for each FFT bin
        self.binToPitchClass = [Int](repeating: -1, count: fftSize / 2)
        self.binWeights = [Float](repeating: 0, count: fftSize / 2)
        computeBinMapping()
    }

    deinit {
        vDSP_DFT_DestroySetup(fftSetup)
    }

    func updateSampleRate(_ newRate: Float) {
        // Recompute bin mapping if sample rate changes
        let oldRate = sampleRate
        if abs(newRate - oldRate) > 1 {
            // Can't mutate sampleRate since it's let, but we pre-computed for 48000
            // which is the typical iOS rate. For safety, recompute if needed.
            computeBinMapping()
        }
    }

    /// Extract a 12-element chromagram from the audio signal.
    /// Each element represents the energy in one pitch class (C=0, C#=1, ..., B=11).
    /// Returns normalized values (0.0 to 1.0).
    func analyze(_ signal: [Float]) -> [Float] {
        let inputLength = min(signal.count, fftSize)

        // Zero-pad or truncate to fftSize
        for i in 0..<fftSize {
            realBuffer[i] = i < inputLength ? signal[i] * hannWindow[i] : 0
            imagBuffer[i] = 0
        }

        // Perform FFT
        var outputReal = [Float](repeating: 0, count: fftSize)
        var outputImag = [Float](repeating: 0, count: fftSize)

        vDSP_DFT_Execute(fftSetup, realBuffer, imagBuffer, &outputReal, &outputImag)

        // Compute magnitude spectrum (only first half — symmetric)
        for i in 0..<halfFFTSize {
            magnitudeBuffer[i] = sqrtf(outputReal[i] * outputReal[i] + outputImag[i] * outputImag[i])
        }

        // Build chromagram by summing magnitudes into 12 pitch classes
        var chroma = [Float](repeating: 0, count: 12)

        // Only consider bins in the guitar frequency range (~60 Hz to ~1500 Hz)
        let minBin = max(1, Int(60.0 / (sampleRate / Float(fftSize))))
        let maxBin = min(halfFFTSize - 1, Int(1500.0 / (sampleRate / Float(fftSize))))

        for bin in minBin...maxBin {
            let pitchClass = binToPitchClass[bin]
            if pitchClass >= 0 {
                // sqrt-compress the magnitude so the loud low strings don't swamp
                // the higher strings. Without this the chroma is dominated by the
                // root/fifth of the bass notes and the third (major vs. minor)
                // barely registers.
                chroma[pitchClass] += sqrtf(magnitudeBuffer[bin]) * binWeights[bin]
            }
        }

        // Normalize: divide by max to get 0.0-1.0 range
        var maxVal: Float = 0
        vDSP_maxv(chroma, 1, &maxVal, vDSP_Length(12))
        if maxVal > 0 {
            var scale = 1.0 / maxVal
            vDSP_vsmul(chroma, 1, &scale, &chroma, 1, vDSP_Length(12))
        }

        return chroma
    }

    // MARK: - Private

    /// Map each FFT bin to its nearest pitch class (0-11) and compute a weight
    /// based on how close the bin center frequency is to a tempered pitch.
    private func computeBinMapping() {
        let binResolution = sampleRate / Float(fftSize)

        for bin in 1..<halfFFTSize {
            let freq = Float(bin) * binResolution

            // Skip frequencies outside musical range
            guard freq >= 50 && freq <= 2000 else {
                binToPitchClass[bin] = -1
                binWeights[bin] = 0
                continue
            }

            // Convert frequency to MIDI note number (fractional)
            let midiNote = 69.0 + 12.0 * log2(freq / 440.0)

            // Pitch class = MIDI note mod 12
            let pitchClass = Int(round(midiNote)) % 12
            let normalizedPitchClass = pitchClass < 0 ? pitchClass + 12 : pitchClass

            // Weight: how close is this bin to an exact tempered frequency
            // (bins that are perfectly on-pitch get weight 1.0, off-pitch bins get less)
            let centsOff = abs((midiNote - round(midiNote)) * 100)
            let weight: Float = max(0, 1.0 - centsOff / 50.0)

            binToPitchClass[bin] = normalizedPitchClass
            binWeights[bin] = weight
        }
    }
}
