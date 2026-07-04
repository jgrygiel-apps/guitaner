import Accelerate

enum SignalPreprocessor {
    /// Cached Hann windows keyed by size, computed on demand.
    private static var hannWindows: [Int: [Float]] = [:]
    private static let lock = NSLock()

    private static func hannWindow(ofSize size: Int) -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        if let cached = hannWindows[size] { return cached }
        var window = [Float](repeating: 0, count: size)
        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HALF_WINDOW))
        hannWindows[size] = window
        return window
    }

    /// Remove DC offset (mean) from signal in-place using vDSP.
    static func removeDCOffset(_ signal: inout [Float]) {
        var mean: Float = 0
        vDSP_meanv(signal, 1, &mean, vDSP_Length(signal.count))
        var negativeMean = -mean
        vDSP_vsadd(signal, 1, &negativeMean, &signal, 1, vDSP_Length(signal.count))
    }

    /// Apply Hann window to signal in-place. Works with any buffer size.
    static func applyHannWindow(_ signal: inout [Float]) {
        let window = hannWindow(ofSize: signal.count)
        vDSP_vmul(signal, 1, window, 1, &signal, 1, vDSP_Length(signal.count))
    }

    /// Compute RMS level in dB. Returns -infinity for silence.
    static func rmsLevelDB(_ signal: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(signal, 1, &rms, vDSP_Length(signal.count))
        guard rms > 0 else { return -.infinity }
        return 20.0 * log10(rms)
    }

    /// Check if signal is above the noise gate threshold.
    static func isAboveNoiseGate(_ signal: [Float], thresholdDB: Float = AudioConstants.noiseGateThresholdDB) -> Bool {
        return rmsLevelDB(signal) > thresholdDB
    }
}
