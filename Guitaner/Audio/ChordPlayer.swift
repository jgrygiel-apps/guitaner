import AVFoundation

/// Plays a sequence of chords (each a set of frequencies) using a sampled
/// instrument (steel-string acoustic guitar) so progressions and chord voicings
/// can be previewed with a natural, realistic tone.
///
/// Backed by `AVAudioUnitSampler` loading the bundled GeneralUser GS SoundFont.
/// The public API (`play`, `stop`, `isPlaying`, `onFinished`) is unchanged from
/// the previous sine-wave implementation, so callers need no changes.
final class ChordPlayer {
    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private var engineStarted = false

    // General MIDI program 25 = Acoustic Guitar (steel). Melodic bank = 0x79.
    private let gmProgram: UInt8 = 25
    private let melodicBankMSB: UInt8 = 0x79
    private let bankLSB: UInt8 = 0x00

    private let queue = DispatchQueue(label: "com.guitaner.chordplayer")
    private var generation = 0
    private var activeNotes: Set<UInt8> = []      // only touched on `queue`
    private(set) var isPlaying = false

    /// Called on the main thread when the sequence finishes (or is stopped).
    var onFinished: (() -> Void)?

    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        loadSoundFont()
    }

    // MARK: - Sound bank

    private func loadSoundFont() {
        guard let url = Bundle.main.url(forResource: "GeneralUser-GS", withExtension: "sf2") else {
            assertionFailure("GeneralUser-GS.sf2 missing from bundle")
            return
        }
        do {
            try sampler.loadSoundBankInstrument(at: url,
                                                program: gmProgram,
                                                bankMSB: melodicBankMSB,
                                                bankLSB: bankLSB)
        } catch {
            // Falls back to the sampler's built-in default tone if loading fails.
            print("ChordPlayer: failed to load SoundFont — \(error)")
        }
    }

    // MARK: - Playback

    /// Plays each chord in sequence. `stepDuration` is the time between chords.
    func play(chords: [[Float]], stepDuration: Double = 2.0) {
        guard !chords.isEmpty else { return }
        startEngineIfNeeded()

        generation += 1
        let gen = generation
        isPlaying = true

        let strum = 0.3      // seconds between successive strings of a chord

        for (i, chord) in chords.enumerated() {
            let stepStart = Double(i) * stepDuration
            let notes = chord.map(midiNote(for:))

            // Release the previous chord right before the new one strums in.
            queue.asyncAfter(deadline: .now() + stepStart) { [weak self] in
                guard let self, self.generation == gen else { return }
                self.releaseAll()
            }

            // Strum the strings low-to-high.
            for (j, note) in notes.enumerated() {
                queue.asyncAfter(deadline: .now() + stepStart + Double(j) * strum) { [weak self] in
                    guard let self, self.generation == gen else { return }
                    self.sampler.startNote(note, withVelocity: 92, onChannel: 0)
                    self.activeNotes.insert(note)
                }
            }
        }

        // Let the final chord ring, then release and report completion.
        let tail = Double(chords.count) * stepDuration + 1.2
        queue.asyncAfter(deadline: .now() + tail) { [weak self] in
            guard let self, self.generation == gen else { return }
            self.releaseAll()
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
        queue.async { [weak self] in self?.releaseAll() }
        if wasPlaying {
            DispatchQueue.main.async { [weak self] in self?.onFinished?() }
        }
    }

    // MARK: - Note helpers

    /// Nearest equal-tempered MIDI note for a frequency (A4 = 440 Hz = note 69).
    private func midiNote(for frequency: Float) -> UInt8 {
        guard frequency > 0 else { return 69 }
        let n = 69.0 + 12.0 * log2(Double(frequency) / 440.0)
        return UInt8(max(0, min(127, Int(n.rounded()))))
    }

    private func releaseAll() {
        for note in activeNotes {
            sampler.stopNote(note, onChannel: 0)
        }
        activeNotes.removeAll()
    }

    // MARK: - Engine

    private func startEngineIfNeeded() {
        guard !engineStarted else { return }

        do {
            try AudioSessionManager.shared.configure(forPlayback: true)
            try AudioSessionManager.shared.activate()
        } catch {}

        engine.prepare()
        do {
            try engine.start()
            engineStarted = true
        } catch {
            engineStarted = false
        }
    }
}
