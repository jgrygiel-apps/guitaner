import SwiftUI

struct TunerView: View {
    @State private var viewModel = TunerViewModel()

    var body: some View {
        ZStack {
            AppBackground()

            if viewModel.permissionDenied {
                permissionDeniedView
            } else {
                tunerContent
            }
        }
        .onAppear {
            viewModel.startTuning()
        }
        .onDisappear {
            viewModel.stopTuning()
        }
    }

    private var tunerContent: some View {
        VStack(spacing: 0) {
            // Top bar: mode toggle + tuning selector
            topBar
                .padding(.top, 12)
                .padding(.horizontal, 20)

            Spacer()

            if viewModel.mode == .manual {
                manualModeContent
            } else {
                autoModeContent
            }

            Spacer()

            // String indicators (tappable in manual mode)
            StringIndicatorView(
                tuning: viewModel.selectedTuning,
                activeIndex: viewModel.activeStringIndex,
                isInTune: viewModel.isInTune,
                isManualMode: viewModel.mode == .manual,
                playingIndex: viewModel.playingStringIndex,
                onStringTap: { index in
                    if viewModel.mode == .manual {
                        viewModel.toggleTone(forStringIndex: index)
                    }
                }
            )
            .padding(.bottom, 32)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Mode toggle
            HStack(spacing: 0) {
                ForEach(TunerMode.allCases, id: \.self) { mode in
                    Button {
                        viewModel.switchMode(mode)
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(viewModel.mode == mode ? .white : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(viewModel.mode == mode ? Color.white.opacity(0.15) : Color.clear)
                            .clipShape(Capsule())
                    }
                }
            }
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())

            Spacer()

            // Tuning selector
            TuningPickerView(
                selected: $viewModel.selectedTuning,
                tunings: viewModel.availableTunings
            )
        }
    }

    // MARK: - Auto Mode

    private var autoModeContent: some View {
        VStack(spacing: 0) {
            // Note display
            NoteDisplayView(
                note: viewModel.currentNote,
                octave: viewModel.currentOctave,
                isInTune: viewModel.isInTune
            )

            // Cents bar indicator (replaces gauge)
            CentsBarView(
                cents: viewModel.centsDeviation,
                isInTune: viewModel.isInTune,
                hasSignal: viewModel.currentNote != "--"
            )
            .frame(height: 40)
            .padding(.horizontal, 24)
            .padding(.top, 12)

            // Frequency & cents readout
            FrequencyDisplayView(
                frequency: viewModel.frequency,
                cents: viewModel.centsDeviation
            )
            .padding(.top, 12)

            // Flowing pitch history chart
            PitchHistoryView(
                history: viewModel.pitchHistory,
                maxCents: AudioConstants.needleMaxCents,
                isInTune: viewModel.isInTune
            )
            .frame(height: 110)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .animation(.linear(duration: 0.05), value: viewModel.pitchHistory.count)

            // Microphone sensitivity slider
            sensitivitySlider
                .padding(.horizontal, 24)
                .padding(.top, 20)
        }
    }

    private var sensitivitySlider: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Sensitivity")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
                Spacer()
            }
            HStack(spacing: 10) {
                Image(systemName: "mic")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.5))
                Slider(value: $viewModel.sensitivity, in: 0...1)
                    .tint(.green.opacity(0.7))
                Image(systemName: "mic.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
    }

    // MARK: - Manual Mode

    private var manualModeContent: some View {
        VStack(spacing: 24) {
            Text("Tap a string to play its reference tone")
                .font(.system(size: 15))
                .foregroundColor(.gray)

            if let index = viewModel.playingStringIndex {
                let note = viewModel.selectedTuning.strings[index]

                VStack(spacing: 8) {
                    Text(note.name)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(.appAccent)

                    Text("\(note.octave)")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundColor(.appAccent.opacity(0.7))

                    Text(String(format: "%.1f Hz", note.frequency))
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 4)

                    // Playing indicator
                    HStack(spacing: 6) {
                        SoundWaveView()
                        Text("Playing")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.appAccent.opacity(0.8))
                    }
                    .padding(.top, 8)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.4))

                    Text("No string selected")
                        .font(.system(size: 16))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
        }
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.red.opacity(0.7))

            Text("Microphone Access Required")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("Guitaner needs access to your microphone to detect pitch. Please enable it in Settings.")
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

// MARK: - Cents Bar (horizontal indicator replacing the gauge)

private struct CentsBarView: View {
    let cents: Float
    let isInTune: Bool
    let hasSignal: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let midX = w / 2

            ZStack {
                // Track background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.06))

                // In-tune zone
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green.opacity(0.1))
                    .frame(width: w * 0.06)

                // Tick marks
                ForEach([-50, -25, 0, 25, 50], id: \.self) { tick in
                    let x = midX + CGFloat(Float(tick) / AudioConstants.needleMaxCents) * (midX - 4)
                    Rectangle()
                        .fill(tick == 0 ? Color.green.opacity(0.4) : Color.gray.opacity(0.3))
                        .frame(width: tick == 0 ? 2 : 1, height: tick == 0 ? h * 0.7 : h * 0.4)
                        .position(x: x, y: h / 2)
                }

                if hasSignal {
                    // Indicator dot
                    let normalized = CGFloat(max(-1, min(1, cents / AudioConstants.needleMaxCents)))
                    let dotX = midX + normalized * (midX - 12)

                    // Glow
                    Circle()
                        .fill(indicatorColor.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .blur(radius: 6)
                        .position(x: dotX, y: h / 2)

                    // Dot
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 14, height: 14)
                        .shadow(color: indicatorColor.opacity(0.5), radius: 3)
                        .position(x: dotX, y: h / 2)
                        .animation(.spring(response: 0.12, dampingFraction: 0.75), value: cents)
                }
            }
        }
    }

    private var indicatorColor: Color {
        if isInTune { return .green }
        let absCents = abs(cents)
        if absCents <= 10 { return .yellow }
        return .orange
    }
}

// MARK: - Sound Wave Animation

private struct SoundWaveView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.appAccent.opacity(0.6))
                    .frame(width: 3, height: animating ? 16 : 6)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}
