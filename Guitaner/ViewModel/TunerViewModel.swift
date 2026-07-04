import Foundation
import AVFoundation
import Observation

enum TunerMode: String, CaseIterable {
    case auto = "Auto"
    case manual = "Manual"
}

@Observable
final class TunerViewModel {
    // MARK: - UI State

    var currentNote: String = "--"
    var currentOctave: Int = 0
    var centsDeviation: Float = 0.0
    var frequency: Float = 0.0
    var confidence: Float = 0.0
    var isInTune: Bool = false
    var isActive: Bool = false
    var activeStringIndex: Int? = nil
    var needlePosition: CGFloat = 0.0
    var pitchHistory: [Float] = []
    private let maxHistoryPoints: Int = 80

    var selectedTuning: TuningDefinition = .standard {
        didSet { tuningEngine.currentTuning = selectedTuning }
    }
    let availableTunings = TuningDefinition.allTunings

    // Mode
    var mode: TunerMode = .auto
    var playingStringIndex: Int? = nil  // which string is playing a tone in manual mode

    // Microphone sensitivity (0 = least, 1 = most). Drives the noise-gate
    // threshold and is persisted across launches.
    var sensitivity: Float = TunerViewModel.loadSensitivity() {
        didSet {
            noiseGateThreshold = TunerViewModel.thresholdDB(for: sensitivity)
            UserDefaults.standard.set(sensitivity, forKey: TunerViewModel.sensitivityKey)
        }
    }
    private var noiseGateThreshold: Float = TunerViewModel.thresholdDB(for: TunerViewModel.loadSensitivity())

    private static let sensitivityKey = "tuner.sensitivity"

    private static func loadSensitivity() -> Float {
        if UserDefaults.standard.object(forKey: sensitivityKey) != nil {
            return UserDefaults.standard.float(forKey: sensitivityKey)
        }
        return AudioConstants.defaultSensitivity
    }

    /// Map a 0...1 sensitivity to a noise-gate threshold in dB (higher sensitivity = lower threshold).
    private static func thresholdDB(for sensitivity: Float) -> Float {
        let t = max(0, min(1, sensitivity))
        return AudioConstants.noiseGateMinThresholdDB
            + t * (AudioConstants.noiseGateMaxThresholdDB - AudioConstants.noiseGateMinThresholdDB)
    }

    var permissionDenied: Bool = false
    var errorMessage: String? = nil

    // MARK: - Dependencies

    private let audioEngine = AudioEngine()
    private let pitchDetector = YINPitchDetector()
    private let pitchTracker = PitchSmoother()
    private let tuningEngine = TuningEngine()
    private let tonePlayer = TonePlayer()

    // Sliding window buffer with overlap
    private var sampleBuffer = [Float]()
    private let analysisSize = AudioConstants.bufferSize
    private let hopSize = AudioConstants.hopSize

    // Silence tracking
    private var silentFrames: Int = 0
    private let silentFramesBeforeClear: Int = 120
    private var lastCents: Float = 0   // held during silence so the chart keeps flowing

    // MARK: - Lifecycle

    func startTuning() {
        Task {
            let granted = await requestMicrophonePermission()
            if granted {
                beginAudioCapture()
            } else {
                await MainActor.run {
                    self.permissionDenied = true
                }
            }
        }
    }

    func stopTuning() {
        audioEngine.stop()
        tonePlayer.stop()
        isActive = false
        pitchTracker.reset()
        sampleBuffer.removeAll()
        silentFrames = 0
        playingStringIndex = nil
        clearDisplay()
    }

    // MARK: - Manual Mode

    /// Toggle playing a reference tone for a string. Tap again to stop.
    func toggleTone(forStringIndex index: Int) {
        if playingStringIndex == index {
            // Stop current tone
            tonePlayer.stop()
            playingStringIndex = nil
        } else {
            // Play tone for this string
            let note = selectedTuning.strings[index]
            do {
                try AudioSessionManager.shared.configure(forPlayback: true)
                try AudioSessionManager.shared.activate()
            } catch {}
            tonePlayer.play(frequency: note.frequency)
            playingStringIndex = index
        }
    }

    func stopTone() {
        tonePlayer.stop()
        playingStringIndex = nil
        // Reconfigure for recording
        do {
            try AudioSessionManager.shared.configure(forPlayback: false)
            try AudioSessionManager.shared.activate()
        } catch {}
    }

    func switchMode(_ newMode: TunerMode) {
        mode = newMode
        if newMode == .auto {
            stopTone()
        }
    }

    // MARK: - Private

    private func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    private func beginAudioCapture() {
        do {
            try AudioSessionManager.shared.configure()
            try AudioSessionManager.shared.activate()

            audioEngine.onBufferReceived = { [weak self] samples in
                self?.processIncomingSamples(samples)
            }

            try audioEngine.start()
            pitchDetector.updateSampleRate(Float(audioEngine.actualSampleRate))

            DispatchQueue.main.async {
                self.isActive = true
                self.errorMessage = nil
            }

            AudioSessionManager.shared.onInterruptionBegan = { [weak self] in
                self?.audioEngine.stop()
                self?.tonePlayer.stop()
                DispatchQueue.main.async {
                    self?.isActive = false
                    self?.playingStringIndex = nil
                }
            }
            AudioSessionManager.shared.onInterruptionEnded = { [weak self] shouldResume in
                if shouldResume {
                    try? self?.audioEngine.start()
                    DispatchQueue.main.async { self?.isActive = true }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start audio: \(error.localizedDescription)"
            }
        }
    }

    private func processIncomingSamples(_ samples: [Float]) {
        sampleBuffer.append(contentsOf: samples)

        while sampleBuffer.count >= analysisSize {
            let frame = Array(sampleBuffer.prefix(analysisSize))
            sampleBuffer.removeFirst(hopSize)
            analyzeFrame(frame)
        }

        if sampleBuffer.count > analysisSize * 4 {
            sampleBuffer.removeFirst(sampleBuffer.count - analysisSize)
        }
    }

    private func analyzeFrame(_ frame: [Float]) {
        var signal = frame

        guard SignalPreprocessor.isAboveNoiseGate(signal, thresholdDB: noiseGateThreshold) else {
            silentFrames += 1

            // Keep the history chart flowing at the last known position so the
            // tuner looks continuously alive even when nothing is being played:
            // the earlier trace scrolls off to the left while the right edge
            // holds the last value.
            DispatchQueue.main.async { [weak self] in
                self?.coastHistory()
            }

            // After a long silence, reset the tracker (once) so the next note
            // locks cleanly — but keep the display coasting, don't hard-clear.
            if silentFrames == silentFramesBeforeClear {
                pitchTracker.reset()
            }
            return
        }

        silentFrames = 0
        SignalPreprocessor.removeDCOffset(&signal)

        let pitchResult = pitchDetector.detectPitch(in: signal)

        let trackedFrequency: Float
        if pitchResult.frequency > 0 {
            trackedFrequency = pitchTracker.smooth(pitchResult.frequency)
        } else {
            trackedFrequency = pitchTracker.smooth(0)
        }

        guard trackedFrequency > 0 else { return }

        let tuningResult = tuningEngine.analyze(
            frequency: trackedFrequency,
            confidence: pitchResult.confidence
        )

        DispatchQueue.main.async { [weak self] in
            self?.updateDisplay(with: tuningResult)
        }
    }

    private func updateDisplay(with result: TuningResult) {
        currentNote = result.nearestNote.name
        currentOctave = result.nearestNote.octave
        centsDeviation = result.centsDeviation
        frequency = result.detectedFrequency
        confidence = result.confidence
        isInTune = result.isInTune
        activeStringIndex = result.matchedStringIndex

        let clampedCents = max(-AudioConstants.needleMaxCents, min(AudioConstants.needleMaxCents, result.centsDeviation))
        needlePosition = CGFloat(clampedCents / AudioConstants.needleMaxCents)

        lastCents = result.centsDeviation
        pitchHistory.append(result.centsDeviation)
        if pitchHistory.count > maxHistoryPoints {
            pitchHistory.removeFirst(pitchHistory.count - maxHistoryPoints)
        }
    }

    /// Advance the history chart during silence by repeating the last known
    /// value, so the graph keeps scrolling and the tuner appears always active.
    private func coastHistory() {
        guard isActive else { return }
        pitchHistory.append(lastCents)
        if pitchHistory.count > maxHistoryPoints {
            pitchHistory.removeFirst(pitchHistory.count - maxHistoryPoints)
        }
    }

    private func clearDisplay() {
        currentNote = "--"
        currentOctave = 0
        centsDeviation = 0
        frequency = 0
        confidence = 0
        isInTune = false
        activeStringIndex = nil
        needlePosition = 0
        pitchHistory.removeAll()
        silentFrames = 0
        lastCents = 0
    }
}
