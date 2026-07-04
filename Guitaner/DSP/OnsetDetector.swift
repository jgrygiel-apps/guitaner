import Foundation

/// Detects note attacks (onsets) in an audio stream using a simple energy-rise
/// method, and reports their absolute time. Used to measure how tightly the
/// player lands on the metronome beat.
final class OnsetDetector {
    var sampleRate: Double = 48000
    var floorDB: Float = -46      // ignore anything quieter than this
    var riseDB: Float = 8         // energy jump (dB) that counts as an attack

    private let hop = 128
    private let refractory = 0.11 // seconds between accepted onsets
    private var envDB: Float = -120
    private var lastOnsetTime: Double = -1

    func reset() {
        envDB = -120
        lastOnsetTime = -1
    }

    /// Returns the absolute times (seconds) of onsets found in this buffer.
    /// `bufferEndTime` is the host time of the buffer's last sample.
    func process(_ samples: [Float], bufferEndTime: Double) -> [Double] {
        var onsets: [Double] = []
        let n = samples.count
        var i = 0

        while i + hop <= n {
            var sum: Float = 0
            for j in i..<(i + hop) {
                sum += samples[j] * samples[j]
            }
            let rms = sqrtf(sum / Float(hop))
            let db = 20 * log10f(rms + 1e-7)

            if db > floorDB && db - envDB > riseDB {
                let onsetTime = bufferEndTime - Double(n - i) / sampleRate
                if onsetTime - lastOnsetTime > refractory {
                    onsets.append(onsetTime)
                    lastOnsetTime = onsetTime
                }
            }

            // Envelope follower: snap up on a rise, release gently otherwise.
            if db > envDB {
                envDB = db
            } else {
                envDB += (db - envDB) * 0.3
            }
            i += hop
        }
        return onsets
    }
}
