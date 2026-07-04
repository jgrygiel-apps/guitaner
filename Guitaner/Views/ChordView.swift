import SwiftUI

struct ChordView: View {
    @State private var viewModel = ChordViewModel()

    var body: some View {
        ZStack {
            AppBackground()

            if viewModel.permissionDenied {
                permissionDeniedView
            } else {
                chordContent
            }
        }
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
    }

    private var chordContent: some View {
        VStack(spacing: 0) {
            // Title
            Text("Chord Detection")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .padding(.top, 16)

            Spacer()

            // Detected chord display
            chordDisplay

            // Chromagram visualization
            ChromagramBarView(chromagram: viewModel.chromagram)
                .frame(height: 120)
                .padding(.horizontal, 20)
                .padding(.top, 24)

            // Confidence
            if viewModel.confidence > 0 {
                HStack(spacing: 4) {
                    Text("Confidence:")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Text(String(format: "%.0f%%", viewModel.confidence * 100))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(confidenceColor)
                }
                .padding(.top, 12)
            }

            Spacer()

            // Recent chords
            if !viewModel.recentChords.isEmpty {
                recentChordsView
                    .padding(.bottom, 32)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.bottom, 8)
            }
        }
    }

    private var chordDisplay: some View {
        VStack(spacing: 4) {
            if viewModel.detectedChord == "--" {
                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.3))
                    .padding(.bottom, 8)

                Text("Play a chord")
                    .font(.system(size: 18))
                    .foregroundColor(.gray.opacity(0.5))
            } else {
                Text(viewModel.detectedChord)
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.detectedChord)
            }
        }
    }

    private var recentChordsView: some View {
        VStack(spacing: 8) {
            Text("Recent")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray.opacity(0.6))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(viewModel.recentChords.enumerated()), id: \.offset) { index, chord in
                        Text(chord)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(index == viewModel.recentChords.count - 1 ? .white : .gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                index == viewModel.recentChords.count - 1
                                    ? Color.white.opacity(0.15)
                                    : Color.white.opacity(0.05)
                            )
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var confidenceColor: Color {
        if viewModel.confidence > 0.75 { return .green }
        if viewModel.confidence > 0.55 { return .yellow }
        return .orange
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.red.opacity(0.7))

            Text("Microphone Access Required")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("Chord detection needs microphone access. Please enable it in Settings.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.appAccent)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Chromagram Bar Visualization

private struct ChromagramBarView: View {
    let chromagram: [Float]

    private let noteNames = ChromagramAnalyzer.pitchClassNames

    var body: some View {
        GeometryReader { geo in
            let barWidth = (geo.size.width - CGFloat(11 * 4)) / 12
            let maxHeight = geo.size.height - 20  // leave room for labels

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<12, id: \.self) { i in
                    VStack(spacing: 4) {
                        Spacer()

                        // Bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(for: chromagram[i]))
                            .frame(width: barWidth, height: max(2, CGFloat(chromagram[i]) * maxHeight))
                            .animation(.easeOut(duration: 0.1), value: chromagram[i])

                        // Label
                        Text(noteNames[i])
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(chromagram[i] > 0.5 ? .white : .gray.opacity(0.6))
                    }
                }
            }
        }
    }

    private func barColor(for value: Float) -> Color {
        if value > 0.7 { return .green }
        if value > 0.4 { return .yellow.opacity(0.8) }
        if value > 0.15 { return .white.opacity(0.3) }
        return .white.opacity(0.08)
    }
}
