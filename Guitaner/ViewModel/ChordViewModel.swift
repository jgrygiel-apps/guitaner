import Foundation
import AVFoundation
import Observation

@Observable
final class ChordViewModel {
    // MARK: - UI State

    var detectedChord: String = "--"
    var detectedQuality: String = ""
    var confidence: Float = 0.0
    var chromagram: [Float] = Array(repeating: 0, count: 12)
    var isActive: Bool = false
    var recentChords: [String] = []

    var permissionDenied: Bool = false
    var errorMessage: String? = nil

    // MARK: - Dependencies

    private let audioEngine = AudioEngine()
    private let chromagramAnalyzer = ChromagramAnalyzer()

    // Buffer management
    private var sampleBuffer = [Float]()
    private let analysisSize = 8192     // larger window for better frequency resolution
    private let hopSize = 4096          // 50% overlap

    // Temporal integration: strums are analysed over several frames ("a few
    // cycles") rather than instant-by-instant. Each analysis frame advances the
    // audio by `hopSize` (~85 ms at 48 kHz), so a handful of frames covers the
    // strum's attack and early sustain — long enough for a stable pitch profile.
    private var smoothedChroma = [Float](repeating: 0, count: 12)
    private let chromaEMAAlpha: Float = 0.35   // blend weight for each new frame
    private var framesSinceOnset: Int = 0
    private let minFramesForMatch: Int = 3     // integrate a few cycles first

    // Chord stability: require consistent detection before showing
    private var candidateChord: String = ""
    private var candidateCount: Int = 0
    private let confirmationsNeeded: Int = 2
    private var lockedChord: String = ""
    private var lockedQuality: String = ""
    private var lockedConfidence: Float = 0

    // Silence tracking
    private var silentFrames: Int = 0
    private let silentFramesBeforeClear: Int = 30

    private let maxRecentChords: Int = 8

    // MARK: - Lifecycle

    func startListening() {
        Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            if granted {
                beginCapture()
            } else {
                await MainActor.run {
                    self.permissionDenied = true
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        isActive = false
        sampleBuffer.removeAll()
        silentFrames = 0
        framesSinceOnset = 0
        clearDisplay()
    }

    // MARK: - Private

    private func beginCapture() {
        do {
            try AudioSessionManager.shared.configure()
            try AudioSessionManager.shared.activate()

            chromagramAnalyzer.updateSampleRate(Float(audioEngine.actualSampleRate))

            audioEngine.onBufferReceived = { [weak self] samples in
                self?.processIncomingSamples(samples)
            }

            try audioEngine.start()
            chromagramAnalyzer.updateSampleRate(Float(audioEngine.actualSampleRate))

            DispatchQueue.main.async {
                self.isActive = true
                self.errorMessage = nil
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
        // Noise gate — true silence resets the integration so the next strum
        // starts from a clean slate.
        guard SignalPreprocessor.isAboveNoiseGate(frame) else {
            framesSinceOnset = 0
            registerNoChord()
            return
        }

        silentFrames = 0

        var signal = frame
        SignalPreprocessor.removeDCOffset(&signal)

        // Extract chromagram for this frame
        let chroma = chromagramAnalyzer.analyze(signal)

        // Integrate over several frames. Seed on the first frame after an onset,
        // then blend subsequent frames in with an EMA so the profile settles as
        // the strum rings out instead of reacting to the noisy attack transient.
        if framesSinceOnset == 0 {
            smoothedChroma = chroma
        } else {
            for i in 0..<12 {
                smoothedChroma[i] = chromaEMAAlpha * chroma[i] + (1 - chromaEMAAlpha) * smoothedChroma[i]
            }
        }
        framesSinceOnset += 1

        // Keep the visualiser live with the integrated profile.
        let displayChroma = smoothedChroma
        DispatchQueue.main.async { [weak self] in
            self?.chromagram = displayChroma
        }

        // Only commit to a chord once a few cycles have been integrated.
        guard framesSinceOnset >= minFramesForMatch else { return }

        // Match the integrated profile against the chord database
        guard let match = ChordDatabase.match(chromagram: smoothedChroma) else {
            registerNoChord()
            return
        }

        // Chord stability: require consistent detections before switching
        let fullName = match.chord.fullName

        if fullName == candidateChord {
            candidateCount += 1
        } else {
            candidateChord = fullName
            candidateCount = 1
        }

        if candidateCount >= confirmationsNeeded && fullName != lockedChord {
            lockedChord = fullName
            lockedQuality = match.chord.quality.rawValue
            lockedConfidence = match.confidence

            // Add to recent chords
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.recentChords.last != fullName {
                    self.recentChords.append(fullName)
                    if self.recentChords.count > self.maxRecentChords {
                        self.recentChords.removeFirst()
                    }
                }
            }
        }

        if !lockedChord.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.detectedChord = self.lockedChord
                self.detectedQuality = self.lockedQuality
                self.confidence = self.lockedConfidence
            }
        }
    }

    /// Count a frame that produced no usable chord toward the silence timeout,
    /// clearing the display once enough have accumulated.
    private func registerNoChord() {
        silentFrames += 1
        if silentFrames >= silentFramesBeforeClear {
            DispatchQueue.main.async { [weak self] in
                self?.clearDisplay()
            }
        }
    }

    private func clearDisplay() {
        detectedChord = "--"
        detectedQuality = ""
        confidence = 0
        chromagram = Array(repeating: 0, count: 12)
        lockedChord = ""
        lockedQuality = ""
        candidateChord = ""
        candidateCount = 0
        silentFrames = 0
        framesSinceOnset = 0
        smoothedChroma = Array(repeating: 0, count: 12)
    }
}
