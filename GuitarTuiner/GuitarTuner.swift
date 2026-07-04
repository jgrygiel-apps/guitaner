//
//  GuitarTuner.swift
//  GuitarTuner
//
//  Created by Jacek Grygiel on 20/02/2025.
//

import Foundation
import CoreAudio
import AVFoundation
import Accelerate

class GuitarTuner: ObservableObject {
    private var audioEngine = AVAudioEngine()
    @Published var detectedFrequency: Float = 0.0
    @Published var harmonicFrequencies: [Float] = []
    @Published var note: String = ""
    @Published var tuningStatus: String = ""
    @Published var deviation: Float = 0.0

    private let notes: [(note: String, frequency: Float)] = [
        ("E", 82.41), ("A", 110.00), ("D", 146.83),
        ("G", 196.00), ("B", 246.94), ("E", 329.63)
    ]

    private let bufferSize = 2048
    private var sampleRate: Float = 44100.0

    func start() {
        configureAudioSession()
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: format) { (buffer, _) in
            self.processAudio(buffer: buffer)
        }

        do {
            try audioEngine.start()
        } catch {
            print("Błąd uruchamiania audioEngine: \(error.localizedDescription)")
        }
    }

    func processAudio(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }


        let bacfFrequency = bitstreamAutocorrelation(samples: channelData, sampleRate: sampleRate)
        print("\(bacfFrequency)")
        DispatchQueue.main.async {
            self.detectedFrequency = bacfFrequency
            self.matchNoteToFrequency(frequency: bacfFrequency)
        }
    }

    func matchNoteToFrequency(frequency: Float) {
        let closestNote = notes.min(by: { abs($0.frequency - frequency) < abs($1.frequency - frequency) })!
        let difference = frequency - closestNote.frequency

        self.note = closestNote.note
        self.deviation = difference
        self.tuningStatus = difference < -1.0 ? "Za nisko" : (difference > 1.0 ? "Za wysoko" : "OK!")
    }

    func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            sampleRate = Float(audioSession.sampleRate)
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            try audioSession.setPreferredSampleRate(Double(sampleRate))
        } catch {
            print("Błąd konfiguracji sesji audio: \(error.localizedDescription)")
        }
    }

    /// **Bitstream Autocorrelation Function (BACF)**
    /// - Converts the input signal into a binary stream and calculates the autocorrelation
    func bitstreamAutocorrelation(samples: UnsafePointer<Float>, sampleRate: Float) -> Float {
        let length = bufferSize
        var bitstream = [UInt8](repeating: 0, count: length)
        var autocorrelation = [Int](repeating: 0, count: length / 2)

        // **Step 1: Convert samples to binary bitstream**
        var meanValue: Float = 0.0
        vDSP_meanv(samples, 1, &meanValue, vDSP_Length(length))

        for i in 0..<length {
            bitstream[i] = samples[i] > meanValue ? 1 : 0
        }

        // **Step 2: Compute autocorrelation**
        for lag in 1..<(length / 2) {
            var sum = 0
            for i in 0..<(length - lag) {
                if bitstream[i] == bitstream[i + lag] {
                    sum += 1
                } else {
                    sum -= 1
                }
            }
            autocorrelation[lag] = sum
        }

        // **Step 3: Find the first peak in autocorrelation**
        let maxLag = length / 2
        var bestLag = 0
        var maxCorr = Int.min

        for lag in 50..<maxLag {
            if autocorrelation[lag] > maxCorr {
                maxCorr = autocorrelation[lag]
                bestLag = lag
            }
        }

        return sampleRate / Float(bestLag)
    }
}

//class GuitarTuner: ObservableObject {
//    private var audioEngine = AVAudioEngine()
//    @Published var detectedFrequency: Float = 0.0
//    @Published var harmonicFrequencies: [Float] = []
//    @Published var note: String = ""
//    @Published var tuningStatus: String = ""
//    @Published var deviation: Float = 0.0
//
//    private let notes: [(note: String, frequency: Float)] = [
//        ("E", 82.41), ("A", 110.00), ("D", 146.83),
//        ("G", 196.00), ("B", 246.94), ("E", 329.63)
//    ]
//
//    private var frequencyBuffer: [Float] = []
//    private let bufferSize = 1
//
//    // Zmienna do przechowywania częstotliwości próbkowania
//    private var sampleRate: Float = 44100.0
//
//    func start() {
//        configureAudioSession()
//
//        let inputNode = audioEngine.inputNode
//        let format = inputNode.outputFormat(forBus: 0)
//
//
//        let bufferSize: AVAudioFrameCount = 8192 // Większy bufor dla wyższej dokładności
//
//        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { (buffer, v) in
//            self.processAudio(buffer: buffer)
//        }
//
//        do {
//            try audioEngine.start()
//        } catch {
//            print("Błąd uruchamiania audioEngine: \(error.localizedDescription)")
//        }
//    }
//
//    func processAudio(buffer: AVAudioPCMBuffer) {
//        guard let channelData = buffer.floatChannelData?[0] else { return }
//
//        // Wykonujemy FFT i próbujemy wyodrębnić częstotliwość z danych audio
//        let fftResult = performFFT(samples: channelData, sampleRate: sampleRate)
////        let acFrequency = autocorrelationPitchDetection(samples: channelData, sampleRate: sampleRate)
//
//        let finalFrequency = validateFrequency(fftResult.peakFrequency, 0)
//        print(finalFrequency)
//        if finalFrequency >= 80 && finalFrequency <= 350 {
//            DispatchQueue.main.async {
//                self.updateFrequencyBuffer(finalFrequency)
//                self.harmonicFrequencies = fftResult.harmonics
//            }
//        }
//    }
//
//    func updateFrequencyBuffer(_ newFrequency: Float) {
//
//        self.detectedFrequency = newFrequency
//        self.matchNoteToFrequency(frequency: newFrequency)
//    }
//
//    func matchNoteToFrequency(frequency: Float) {
//        let closestNote = notes.min(by: { abs($0.frequency - frequency) < abs($1.frequency - frequency) })!
//        let difference = frequency - closestNote.frequency
//
//        self.note = closestNote.note
//        self.deviation = difference
//        self.tuningStatus = difference < -1.0 ? "Za nisko" : (difference > 1.0 ? "Za wysoko" : "OK!")
//    }
//
//    func configureAudioSession() {
//        let audioSession = AVAudioSession.sharedInstance()
//        do {
//            // Pobieranie rzeczywistej częstotliwości próbkowania z urządzenia
//            sampleRate = Float(audioSession.sampleRate)
//
//            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetooth, .defaultToSpeaker])
//            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
//            try audioSession.setPreferredSampleRate(Double(sampleRate))
//        } catch {
//            print("Błąd konfiguracji sesji audio: \(error.localizedDescription)")
//        }
//    }
//
//    // FFT - obliczenie podstawowej częstotliwości i harmonicznych
//    func performFFT(samples: UnsafePointer<Float>, sampleRate: Float) -> (peakFrequency: Float, harmonics: [Float]) {
//        let frameLength = 8192  // Większy rozmiar bufora
//        var realParts = [Float](repeating: 0, count: frameLength)
//        var imaginaryParts = [Float](repeating: 0, count: frameLength)
//        var magnitudes = [Float](repeating: 0, count: frameLength / 2)
//
//        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imaginaryParts)
//        let log2n = vDSP_Length(log2(Double(frameLength)))
//        let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
//
//        // Zastosowanie okna Hanninga
//        var window = [Float](repeating: 0, count: frameLength)
//        vDSP_hann_window(&window, vDSP_Length(frameLength), Int32(vDSP_HANN_NORM))
//        vDSP_vmul(samples, 1, window, 1, &realParts, 1, vDSP_Length(frameLength))
//
//        // Konwersja na format FFT
//        samples.withMemoryRebound(to: DSPComplex.self, capacity: frameLength) {
//            vDSP_ctoz($0, 2, &splitComplex, 1, vDSP_Length(frameLength / 2))
//        }
//
//        // FFT
//        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
//
//        // Obliczenie mocy widma
//        vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(frameLength / 2))
//
//        vDSP_destroy_fftsetup(fftSetup)
//
//        // Znalezienie najczęstszej wartości
//        let maxIndex = magnitudes.indices.max(by: { magnitudes[$0] < magnitudes[$1] }) ?? 0
//        let peakFrequency = Float(maxIndex) * (sampleRate / Float(frameLength))
//
//        // Harmoniczne (pomijamy najniższą częstotliwość - podstawową)
//        var harmonics: [Float] = []
//        let harmonicCount = 5
//        for i in 2...harmonicCount {
//            let harmonicFrequency = peakFrequency * Float(i)
//            harmonics.append(harmonicFrequency)
//        }
//
//        return (peakFrequency, harmonics)
//    }
//
//    // Autokorelacja - do wykrywania podstawowej częstotliwości
//    func autocorrelationPitchDetection(samples: UnsafePointer<Float>, sampleRate: Float) -> Float {
//        let length = 8192  // Zwiększ rozmiar
//        var maxLag: Int = 0
//        var maxCorr: Float = -Float.infinity
//        var bestPitch: Float = 0
//
//        for lag in 50..<length / 2 {
//            var correlation: Float = 0
//            for i in 0..<(length - lag) {
//                correlation += samples[i] * samples[i + lag]
//            }
//            correlation /= Float(length - lag)
//
//            if correlation > maxCorr {
//                maxCorr = correlation
//                maxLag = lag
//            }
//        }
//
//        bestPitch = sampleRate / Float(maxLag)
//
//        return bestPitch
//    }
//
//    // Walidacja częstotliwości z FFT i autokorelacji
//    func validateFrequency(_ fftFreq: Float, _ acFreq: Float) -> Float {
////        if abs(fftFreq - acFreq) < 5 {
////            return fftFreq
////        }
////
////        if acFreq >= 80 && acFreq <= 350 {
////            return acFreq
////        }
//
//        return fftFreq
//    }
//}
