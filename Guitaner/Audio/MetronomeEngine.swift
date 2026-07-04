import AVFoundation

/// Produces short metronome clicks on demand (accented downbeat vs. regular beat).
/// Timing/scheduling is owned by the caller so it can share a clock with analysis.
final class MetronomeEngine {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var sampleRate: Float = 44100
    private var started = false

    // Single click "voice"
    private var level: Float = 0
    private var phase: Float = 0
    private var frequency: Float = 1000
    private var decay: Float = 0.999
    private let lock = NSLock()

    func start() {
        guard !started else { return }

        let format = engine.outputNode.outputFormat(forBus: 0)
        sampleRate = Float(format.sampleRate)
        decay = powf(0.001, 1.0 / (0.045 * sampleRate))   // ~45 ms click

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, ablList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(ablList)
            let twoPi = 2.0 * Float.pi

            self.lock.lock()
            for frame in 0..<Int(frameCount) {
                var value: Float = 0
                if self.level > 0.0002 {
                    value = self.level * sinf(self.phase)
                    self.phase += twoPi * self.frequency / self.sampleRate
                    if self.phase >= twoPi { self.phase -= twoPi }
                    self.level *= self.decay
                }
                for buffer in abl {
                    let buf = UnsafeMutableBufferPointer<Float>(buffer)
                    buf[frame] = value
                }
            }
            self.lock.unlock()
            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.prepare()
        do {
            try engine.start()
            started = true
        } catch {
            started = false
        }
    }

    func click(accent: Bool) {
        lock.lock()
        frequency = accent ? 1600 : 1000
        level = accent ? 0.6 : 0.4
        phase = 0
        lock.unlock()
    }

    func stop() {
        lock.lock(); level = 0; lock.unlock()
        if started {
            engine.stop()
            if let node = sourceNode {
                engine.disconnectNodeOutput(node)
                engine.detach(node)
                sourceNode = nil
            }
            started = false
        }
    }
}
