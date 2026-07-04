import AVFoundation

/// Plays a sequence of chords (each a set of frequencies) with a light strum and
/// a plucked decay envelope, so a progression can be previewed by ear.
final class ChordPlayer {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var sampleRate: Float = 44100
    private var engineStarted = false

    private struct Voice {
        var frequency: Float = 0
        var phase: Float = 0
        var level: Float = 0
        var target: Float = 0
        var attackStep: Float = 0
        var decay: Float = 0.9999
        var delay: Int = 0        // strum delay (samples) before the note sounds
    }

    private let voiceCount = 6
    private var voices: [Voice]
    private let lock = NSLock()

    private let queue = DispatchQueue(label: "com.guitaner.chordplayer")
    private var generation = 0
    private(set) var isPlaying = false

    /// Called on the main thread when the sequence finishes (or is stopped).
    var onFinished: (() -> Void)?

    init() {
        voices = [Voice](repeating: Voice(), count: voiceCount)
    }

    // MARK: - Playback

    func play(chords: [[Float]], stepDuration: Double = 0.85) {
        guard !chords.isEmpty else { return }
        startEngineIfNeeded()

        lock.lock()
        voices = [Voice](repeating: Voice(), count: voiceCount)
        lock.unlock()

        generation += 1
        let gen = generation
        isPlaying = true

        for (i, chord) in chords.enumerated() {
            queue.asyncAfter(deadline: .now() + Double(i) * stepDuration) { [weak self] in
                guard let self, self.generation == gen else { return }
                self.trigger(chord)
            }
        }

        let tail = Double(chords.count) * stepDuration + 0.7
        queue.asyncAfter(deadline: .now() + tail) { [weak self] in
            guard let self, self.generation == gen else { return }
            self.silence()
            DispatchQueue.main.async {
                self.isPlaying = false
                self.onFinished?()
            }
        }
    }

    func stop() {
        generation += 1
        let wasPlaying = isPlaying
        isPlaying = false
        silence()
        if wasPlaying {
            DispatchQueue.main.async { [weak self] in self?.onFinished?() }
        }
    }

    // MARK: - Voice control

    private func silence() {
        lock.lock()
        for i in voices.indices {
            voices[i].target = 0
            voices[i].delay = 0
        }
        lock.unlock()
    }

    private func trigger(_ frequencies: [Float]) {
        let strumSamples = Int(0.022 * sampleRate)
        let attackSamples = max(1, 0.006 * sampleRate)
        let voiceTarget: Float = 0.11
        let decayPerSample = powf(0.0008, 1.0 / (1.6 * sampleRate))  // ~1.6 s to near-silence

        lock.lock()
        for i in voices.indices {
            if i < frequencies.count {
                voices[i].frequency = frequencies[i]
                voices[i].phase = 0
                voices[i].level = 0
                voices[i].target = voiceTarget
                voices[i].attackStep = voiceTarget / attackSamples
                voices[i].decay = decayPerSample
                voices[i].delay = i * strumSamples
            } else {
                voices[i].target = 0    // let any leftover voice decay out
                voices[i].delay = 0
            }
        }
        lock.unlock()
    }

    // MARK: - Engine

    private func startEngineIfNeeded() {
        guard !engineStarted else { return }

        do {
            try AudioSessionManager.shared.configure(forPlayback: true)
            try AudioSessionManager.shared.activate()
        } catch {}

        let format = engine.outputNode.outputFormat(forBus: 0)
        sampleRate = Float(format.sampleRate)

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, ablList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(ablList)
            let frames = Int(frameCount)
            let twoPi = 2.0 * Float.pi

            self.lock.lock()
            for frame in 0..<frames {
                var sample: Float = 0
                for v in 0..<self.voiceCount {
                    if self.voices[v].delay > 0 {
                        self.voices[v].delay -= 1
                        continue
                    }
                    // Envelope: linear attack to target, then exponential decay.
                    if self.voices[v].level < self.voices[v].target {
                        self.voices[v].level += self.voices[v].attackStep
                        if self.voices[v].level > self.voices[v].target {
                            self.voices[v].level = self.voices[v].target
                        }
                    } else {
                        self.voices[v].level *= self.voices[v].decay
                    }

                    let lvl = self.voices[v].level
                    let freq = self.voices[v].frequency
                    if lvl > 0.0001 && freq > 0 {
                        sample += lvl * sinf(self.voices[v].phase)
                        self.voices[v].phase += twoPi * freq / self.sampleRate
                        if self.voices[v].phase >= twoPi { self.voices[v].phase -= twoPi }
                    }
                }
                for buffer in abl {
                    let buf = UnsafeMutableBufferPointer<Float>(buffer)
                    buf[frame] = sample
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
            engineStarted = true
        } catch {
            engineStarted = false
        }
    }
}
