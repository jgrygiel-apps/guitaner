//
//  GuitarTuinerApp.swift
//  GuitarTuiner
//
//  Created by Jacek Grygiel on 20/02/2025.
//

import SwiftUI
import Charts

@main
struct GuitarTuinerApp: App {
    var body: some Scene {
        WindowGroup {
            TunerView()
        }
    }
}

struct TunerView: View {
    @ObservedObject var tuner = GuitarTuner()

    var body: some View {
        VStack {
            Text("🎸 Guitar Tuner")
                .font(.largeTitle)
                .padding()

            Text("Frequency: \(String(format: "%.2f", tuner.detectedFrequency)) Hz")
                .font(.title2)
                .padding()

            Text("Sound: \(tuner.note)")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.blue)
                .padding()

            HarmonicChart(harmonics: tuner.harmonicFrequencies)

            Text("Status: \(tuner.tuningStatus)")
                .font(.title)
                .foregroundColor(tuner.tuningStatus == "OK!" ? .green : .red)
                .padding()

            Button("Start") {
                tuner.start()
            }
            .font(.title)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
    }
}

struct HarmonicChart: View {
    var harmonics: [Float]

    var body: some View {
        VStack {
            Text("Harmonic frequencies")
                .font(.headline)
                .padding()

            Chart {
                ForEach(0..<harmonics.count, id: \.self) { index in
                    BarMark(
                        x: .value("Harmonic", harmonics[index]),
                        y: .value("Amplitude", Float(index) * 10)
                    )
                }
            }
            .frame(height: 300)
        }
    }
}

#Preview {
    TunerView(tuner: GuitarTuner())
}
