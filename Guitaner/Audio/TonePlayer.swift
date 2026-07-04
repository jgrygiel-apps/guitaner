import AVFoundation

/// Generates a pure sine wave tone at a given frequency using AVAudioSourceNode.
final class TonePlayer {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var currentFrequency: Float = 0
    private var phase: Float = 0
    private var isPlaying = false
    private let amplitude: Float = 0.25

    func play(frequency: Float) {
        stop()

        currentFrequency = frequency
        phase = 0

        let sampleRate = Float(engine.outputNode.outputFormat(forBus: 0).sampleRate)

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let phaseIncrement = 2.0 * Float.pi * self.currentFrequency / sampleRate

            for frame in 0..<Int(frameCount) {
                let value = self.amplitude * sinf(self.phase)
                self.phase += phaseIncrement
                if self.phase >= 2.0 * Float.pi {
                    self.phase -= 2.0 * Float.pi
                }

                for buffer in ablPointer {
                    let buf = UnsafeMutableBufferPointer<Float>(buffer)
                    buf[frame] = value
                }
            }
            return noErr
        }

        sourceNode = node

        let format = engine.outputNode.outputFormat(forBus: 0)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        do {
            engine.prepare()
            try engine.start()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        guard isPlaying else { return }
        engine.stop()
        if let node = sourceNode {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
            sourceNode = nil
        }
        isPlaying = false
    }

    var playing: Bool { isPlaying }
}
