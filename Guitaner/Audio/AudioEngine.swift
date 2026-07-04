import AVFoundation
import QuartzCore

final class AudioEngine {
    private let engine = AVAudioEngine()
    private let processingQueue = DispatchQueue(label: "com.guitaner.dsp", qos: .userInteractive)

    var onBufferReceived: (([Float]) -> Void)?
    /// Same as `onBufferReceived` but also passes the host time (seconds) captured
    /// in the tap — used by the practice timing analyser.
    var onBufferReceivedWithTime: (([Float], Double) -> Void)?
    private(set) var actualSampleRate: Double = Double(AudioConstants.sampleRate)

    /// Tap buffer size. Smaller = lower latency (used by the practice analyser).
    /// Set before calling `start()`.
    var tapBufferSize: Int = AudioConstants.bufferSize

    private var isRunning = false

    func start() throws {
        guard !isRunning else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        actualSampleRate = inputFormat.sampleRate

        let bufferSize = AVAudioFrameCount(tapBufferSize)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let channelData = buffer.floatChannelData else { return }

            let hostTime = CACurrentMediaTime()
            let frameCount = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)

            // Copy to a Swift array on the audio thread (no allocations after first call due to ARC)
            var samples = [Float](repeating: 0, count: frameCount)

            if channelCount == 1 {
                memcpy(&samples, channelData[0], frameCount * MemoryLayout<Float>.size)
            } else {
                // Mix stereo to mono
                let left = UnsafeBufferPointer(start: channelData[0], count: frameCount)
                let right = UnsafeBufferPointer(start: channelData[1], count: frameCount)
                for i in 0..<frameCount {
                    samples[i] = (left[i] + right[i]) * 0.5
                }
            }

            self.processingQueue.async {
                self.onBufferReceived?(samples)
                self.onBufferReceivedWithTime?(samples, hostTime)
            }
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }
}
