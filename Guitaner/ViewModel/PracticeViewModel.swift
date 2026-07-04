import Foundation
import AVFoundation
import Observation
import QuartzCore

@Observable
final class PracticeViewModel {
    // MARK: - Settings

    var bpm: Double = 90 {
        didSet { if isRunning { restartGrid() } }
    }
    var beatsPerBar: Int = 4
    var latencyOffsetMs: Double = 0    // manual calibration nudge
    var useHeadphones: Bool = true {
        didSet { if isRunning { restartAudio() } }
    }

    // MARK: - UI State

    var isRunning = false
    var currentBeat: Int = 0           // 0-based beat within the bar (for pulse)
    var beatPulse: Int = 0             // increments each beat to drive animation
    var permissionDenied = false

    struct Hit: Identifiable {
        let id = UUID()
        let time: Double               // absolute onset time (CACurrentMediaTime)
        let deviation: Double          // seconds early(-)/late(+) vs nearest beat
    }
    var hits: [Hit] = []
    private let maxHits = 80

    // Stats over recent hits
    var avgAbsMs: Double = 0
    var tightPercent: Double = 0

    // Timing grid (exposed for the timeline view)
    private(set) var anchor: Double = 0
    private(set) var secondsPerBeat: Double = 0.667

    // MARK: - Dependencies

    private let audioEngine = AudioEngine()
    private let metronome = MetronomeEngine()
    private let onsetDetector = OnsetDetector()
    private var timer: DispatchSourceTimer?
    private var beatCounter = 0
    private var inputLatency: Double = 0
    private var outputLatency: Double = 0
    private let tightWindow = 0.030    // ±30 ms counts as "tight"

    // MARK: - Lifecycle

    func start() {
        Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            await MainActor.run {
                if granted { self.begin() } else { self.permissionDenied = true }
            }
        }
    }

    func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
        audioEngine.stop()
        metronome.stop()
    }

    var tightWindowMs: Double { tightWindow * 1000 }

    // MARK: - Private

    private func begin() {
        do {
            try AudioSessionManager.shared.configureForPractice(useHeadphones: useHeadphones)
            try AudioSessionManager.shared.activate()
        } catch {}

        let session = AVAudioSession.sharedInstance()
        inputLatency = session.inputLatency
        outputLatency = session.outputLatency

        metronome.start()
        onsetDetector.reset()

        audioEngine.tapBufferSize = 256    // ~5 ms blocks for low-latency onset timing
        audioEngine.onBufferReceivedWithTime = { [weak self] samples, hostTime in
            self?.handleBuffer(samples, hostTime: hostTime)
        }
        try? audioEngine.start()
        onsetDetector.sampleRate = audioEngine.actualSampleRate

        hits = []
        avgAbsMs = 0
        tightPercent = 0
        secondsPerBeat = 60.0 / bpm
        anchor = CACurrentMediaTime()
        beatCounter = 0
        isRunning = true
        scheduleTimer()
    }

    private func restartGrid() {
        secondsPerBeat = 60.0 / bpm
        anchor = CACurrentMediaTime()
        beatCounter = 0
        onsetDetector.reset()
        scheduleTimer()
    }

    /// Full audio restart (needed when switching headphones/speaker routing).
    private func restartAudio() {
        timer?.cancel()
        audioEngine.stop()
        metronome.stop()
        begin()
    }

    private func scheduleTimer() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        t.schedule(deadline: .now(), repeating: secondsPerBeat, leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }

    private func tick() {
        let beatInBar = beatCounter % max(1, beatsPerBar)
        metronome.click(accent: beatInBar == 0)
        beatCounter += 1
        DispatchQueue.main.async {
            self.currentBeat = beatInBar
            self.beatPulse &+= 1
        }
    }

    private func handleBuffer(_ samples: [Float], hostTime: Double) {
        guard isRunning else { return }

        // Acoustic time of the buffer's last sample (compensate mic input latency).
        let bufferEndTime = hostTime - inputLatency
        let onsets = onsetDetector.process(samples, bufferEndTime: bufferEndTime)
        guard !onsets.isEmpty else { return }

        var newHits: [Hit] = []
        for onset in onsets {
            let k = ((onset - anchor) / secondsPerBeat).rounded()
            let nearestBeat = anchor + k * secondsPerBeat

            // In speaker mode the click bleeds into the mic as a transient right at
            // the beat; reject that short window so it isn't counted as a phantom hit.
            if !useHeadphones {
                let sinceClick = onset - nearestBeat - outputLatency
                if sinceClick >= -0.010 && sinceClick <= 0.035 { continue }
            }

            // The click is heard `outputLatency` after the grid time, so a player
            // in time with what they hear is centred by subtracting it.
            let deviation = (onset - nearestBeat) - outputLatency - latencyOffsetMs / 1000.0
            newHits.append(Hit(time: onset, deviation: deviation))
        }

        DispatchQueue.main.async {
            self.hits.append(contentsOf: newHits)
            if self.hits.count > self.maxHits {
                self.hits.removeFirst(self.hits.count - self.maxHits)
            }
            self.updateStats()
        }
    }

    private func updateStats() {
        let recent = hits.suffix(24)
        guard !recent.isEmpty else {
            avgAbsMs = 0
            tightPercent = 0
            return
        }
        let absMs = recent.map { abs($0.deviation) * 1000 }
        avgAbsMs = absMs.reduce(0, +) / Double(absMs.count)
        let tight = recent.filter { abs($0.deviation) <= tightWindow }.count
        tightPercent = Double(tight) / Double(recent.count) * 100
    }
}
