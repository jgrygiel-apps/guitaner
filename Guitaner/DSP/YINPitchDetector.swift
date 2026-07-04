import Foundation
import Accelerate

/// Result of pitch detection for a single audio frame.
struct PitchResult {
    let frequency: Float
    let confidence: Float

    static let noResult = PitchResult(frequency: 0, confidence: 0)
}

/// YIN pitch detection algorithm (de Cheveigne & Kawahara, 2002).
///
/// Implements all 6 steps of the YIN algorithm:
/// 1. Difference function
/// 2. Cumulative mean normalized difference function
/// 3. Absolute thresholding
/// 4. Parabolic interpolation
/// 5. Best local estimate
/// 6. Best local pitch
final class YINPitchDetector {
    private var sampleRate: Float
    private let bufferSize: Int
    private let halfBufferSize: Int
    private let threshold: Float

    // Pre-allocated buffers to avoid per-frame allocations
    private var differenceBuffer: [Float]
    private var cmndfBuffer: [Float]
    private var tempBuffer: [Float]

    init(
        sampleRate: Float = AudioConstants.sampleRate,
        bufferSize: Int = AudioConstants.bufferSize,
        threshold: Float = AudioConstants.yinThreshold
    ) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.halfBufferSize = bufferSize / 2
        self.threshold = threshold

        self.differenceBuffer = [Float](repeating: 0, count: bufferSize / 2)
        self.cmndfBuffer = [Float](repeating: 0, count: bufferSize / 2)
        self.tempBuffer = [Float](repeating: 0, count: bufferSize / 2)
    }

    /// Update the sample rate (call when audio engine reports actual hardware rate).
    func updateSampleRate(_ newRate: Float) {
        sampleRate = newRate
    }

    /// Tau range computed from the current sample rate.
    private var tauMin: Int {
        max(2, Int(sampleRate / AudioConstants.yinMaxFrequency))
    }

    private var tauMax: Int {
        min(Int(sampleRate / AudioConstants.yinMinFrequency), halfBufferSize - 2)
    }

    /// Detect pitch in the given audio signal.
    /// - Parameter signal: Audio samples (expected length = bufferSize).
    /// - Returns: Detected pitch frequency and confidence, or `.noResult` if no pitch found.
    func detectPitch(in signal: [Float]) -> PitchResult {
        guard signal.count >= bufferSize else { return .noResult }

        // Step 1: Difference function
        computeDifferenceFunction(signal)

        // Step 2: Cumulative mean normalized difference function
        computeCMNDF()

        // Step 3: Absolute thresholding — find the first tau below threshold
        guard let bestTau = findBestTau() else {
            return .noResult
        }

        // Step 4: Parabolic interpolation for sub-sample accuracy
        let refinedTau = parabolicInterpolation(around: bestTau)

        // Step 5 & 6: Compute frequency and confidence
        guard refinedTau > 0 else { return .noResult }

        let frequency = sampleRate / refinedTau
        let confidence = 1.0 - cmndfBuffer[bestTau]

        // Sanity check: reject frequencies outside expected range
        guard frequency >= AudioConstants.yinMinFrequency,
              frequency <= AudioConstants.yinMaxFrequency else {
            return .noResult
        }

        return PitchResult(frequency: frequency, confidence: max(0, min(1, confidence)))
    }

    // MARK: - Step 1: Difference Function
    //
    // d(tau) = sum_{j=0}^{W-1} (x[j] - x[j + tau])^2

    private func computeDifferenceFunction(_ signal: [Float]) {
        let W = halfBufferSize

        differenceBuffer[0] = 0

        signal.withUnsafeBufferPointer { signalPtr in
            let base = signalPtr.baseAddress!

            for tau in 1..<W {
                var sum: Float = 0
                // vDSP_vsub computes C[i] = B[i] - A[i]
                // We want tempBuffer[i] = signal[i] - signal[i + tau]
                // So A = base+tau, B = base → C = base[i] - (base+tau)[i]
                vDSP_vsub(base + tau, 1, base, 1, &self.tempBuffer, 1, vDSP_Length(W))
                vDSP_dotpr(self.tempBuffer, 1, self.tempBuffer, 1, &sum, vDSP_Length(W))
                self.differenceBuffer[tau] = sum
            }
        }
    }

    // MARK: - Step 2: Cumulative Mean Normalized Difference Function
    //
    // d'(0) = 1
    // d'(tau) = d(tau) / ((1/tau) * sum_{j=1}^{tau} d(j))
    //         = d(tau) * tau / sum_{j=1}^{tau} d(j)

    private func computeCMNDF() {
        cmndfBuffer[0] = 1.0

        var runningSum: Float = 0

        for tau in 1..<halfBufferSize {
            runningSum += differenceBuffer[tau]

            if runningSum < 1e-10 {
                cmndfBuffer[tau] = 1.0
            } else {
                cmndfBuffer[tau] = differenceBuffer[tau] * Float(tau) / runningSum
            }
        }
    }

    // MARK: - Step 3: Absolute Thresholding
    //
    // Find the first tau (starting from tauMin) where CMNDF dips below threshold.
    // Then find the local minimum within that dip (best local estimate — Step 5).

    private func findBestTau() -> Int? {
        let minTau = tauMin
        let maxTau = tauMax

        guard minTau < maxTau else { return nil }

        // Find the first tau where CMNDF dips below threshold,
        // then search the entire dip region for the true minimum.
        var tau = minTau
        while tau <= maxTau {
            if cmndfBuffer[tau] < threshold {
                // Entered a dip — find the minimum within this dip
                var bestTau = tau
                tau += 1
                while tau <= maxTau && cmndfBuffer[tau] < threshold {
                    if cmndfBuffer[tau] < cmndfBuffer[bestTau] {
                        bestTau = tau
                    }
                    tau += 1
                }
                return bestTau
            }
            tau += 1
        }

        // No value below threshold — fall back to global minimum
        var globalMinTau = minTau
        for tau in (minTau + 1)...maxTau {
            if cmndfBuffer[tau] < cmndfBuffer[globalMinTau] {
                globalMinTau = tau
            }
        }

        // Accept with lower confidence
        if cmndfBuffer[globalMinTau] < 0.5 {
            return globalMinTau
        }

        return nil
    }

    // MARK: - Step 4: Parabolic Interpolation
    //
    // Refine the integer tau to sub-sample accuracy using 3-point quadratic fit:
    // betterTau = tau + 0.5 * (alpha - gamma) / (alpha - 2*beta + gamma)

    private func parabolicInterpolation(around tau: Int) -> Float {
        guard tau > 0, tau < halfBufferSize - 1 else {
            return Float(tau)
        }

        let alpha = cmndfBuffer[tau - 1]
        let beta = cmndfBuffer[tau]
        let gamma = cmndfBuffer[tau + 1]

        let denominator = alpha - 2.0 * beta + gamma

        guard abs(denominator) > 1e-12 else {
            return Float(tau)
        }

        let adjustment = 0.5 * (alpha - gamma) / denominator
        return Float(tau) + adjustment
    }
}
