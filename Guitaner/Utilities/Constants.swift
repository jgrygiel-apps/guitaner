import Foundation

enum AudioConstants {
    static let sampleRate: Float = 44100.0
    static let bufferSize: Int = 4096
    static let hopSize: Int = 1024             // more overlap = smoother tracking
    static let preferredIOBufferDuration: TimeInterval = Double(1024) / Double(sampleRate)

    static let yinThreshold: Float = 0.22      // a touch more permissive — catches decaying notes
    static let yinMinFrequency: Float = 60.0
    static let yinMaxFrequency: Float = 1400.0

    static var yinTauMin: Int { Int(sampleRate / yinMaxFrequency) }
    static var yinTauMax: Int { Int(sampleRate / yinMinFrequency) }

    static let noiseGateThresholdDB: Float = -72.0  // even more sensitive for phone mic

    // User-adjustable sensitivity (slider). Maps a 0...1 value to the noise-gate
    // threshold in dB: 0 = least sensitive (needs a louder note), 1 = most sensitive.
    static let noiseGateMinThresholdDB: Float = -50.0   // slider = 0
    static let noiseGateMaxThresholdDB: Float = -84.0   // slider = 1
    static let defaultSensitivity: Float = 0.73         // ≈ -72 dB, matches current feel

    static let smootherMedianWindowSize: Int = 7
    static let smootherEMAAlpha: Float = 0.15       // slower, more stable
    static let smootherResetThresholdCents: Float = 80.0

    static let inTuneToleranceCents: Float = 3.0
    static let needleMaxCents: Float = 50.0
}
