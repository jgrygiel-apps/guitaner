import SwiftUI
import QuartzCore

struct PracticeView: View {
    @State private var viewModel = PracticeViewModel()
    @State private var showCalibration = false

    private let maxDevMs: Double = 80          // full-scale deviation for the visuals

    var body: some View {
        ZStack {
            AppBackground()

            if viewModel.permissionDenied {
                Text("Microphone access is required for practice timing.")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(40)
            } else {
                VStack(spacing: 18) {
                    header
                    bpmControl
                    beatsPerBarPicker
                    headphonesToggle
                    beatPulse
                    deviationMeter
                    timeline
                    stats
                    if showCalibration { calibration }
                    Spacer()
                    startStopButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Practice")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Button {
                showCalibration.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - BPM

    private var bpmControl: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(viewModel.bpm))")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text("BPM")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
            HStack(spacing: 14) {
                stepButton("-") { viewModel.bpm = max(40, viewModel.bpm - 1) }
                Slider(value: $viewModel.bpm, in: 40...240, step: 1)
                    .tint(.green.opacity(0.8))
                stepButton("+") { viewModel.bpm = min(240, viewModel.bpm + 1) }
            }
        }
    }

    private func stepButton(_ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 40, height: 36)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Beats per bar

    private var beatsPerBarPicker: some View {
        HStack(spacing: 8) {
            ForEach([2, 3, 4, 6], id: \.self) { count in
                Button {
                    viewModel.beatsPerBar = count
                } label: {
                    Text("\(count)/4")
                        .font(.system(size: 13, weight: viewModel.beatsPerBar == count ? .semibold : .regular))
                        .foregroundColor(viewModel.beatsPerBar == count ? .white : .gray)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(viewModel.beatsPerBar == count ? Color.appAccent.opacity(0.8) : Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Headphones toggle

    private var headphonesToggle: some View {
        VStack(spacing: 4) {
            Toggle(isOn: $viewModel.useHeadphones) {
                HStack(spacing: 6) {
                    Image(systemName: "headphones")
                        .font(.system(size: 14))
                    Text("Headphones mode")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
            }
            .tint(.green)

            if !viewModel.useHeadphones {
                HStack {
                    Text("Speaker mode: the click may leak into the mic — use headphones for best accuracy.")
                        .font(.system(size: 10))
                        .foregroundColor(.orange.opacity(0.7))
                    Spacer()
                }
            }
        }
    }

    // MARK: - Beat pulse dots

    private var beatPulse: some View {
        HStack(spacing: 10) {
            ForEach(0..<viewModel.beatsPerBar, id: \.self) { index in
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: index == 0 ? 16 : 12, height: index == 0 ? 16 : 12)
                    .scaleEffect(viewModel.isRunning && viewModel.currentBeat == index ? 1.35 : 1.0)
                    .animation(.easeOut(duration: 0.12), value: viewModel.beatPulse)
            }
        }
        .frame(height: 20)
    }

    private func dotColor(for index: Int) -> Color {
        guard viewModel.isRunning, viewModel.currentBeat == index else {
            return .white.opacity(0.15)
        }
        return index == 0 ? .green : .white.opacity(0.85)
    }

    // MARK: - Deviation meter (last hit)

    private var deviationMeter: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let midX = w / 2
            let last = viewModel.hits.last

            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05))

                // tight zone
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green.opacity(0.12))
                    .frame(width: w * CGFloat(viewModel.tightWindowMs / maxDevMs))

                // center line
                Rectangle().fill(Color.green.opacity(0.5)).frame(width: 2)

                Text("early").font(.system(size: 9)).foregroundColor(.gray.opacity(0.5))
                    .position(x: 26, y: h - 8)
                Text("late").font(.system(size: 9)).foregroundColor(.gray.opacity(0.5))
                    .position(x: w - 22, y: h - 8)

                if let last {
                    let devMs = last.deviation * 1000
                    let norm = CGFloat(max(-1, min(1, devMs / maxDevMs)))
                    let x = midX + norm * (midX - 10)
                    Circle()
                        .fill(color(forMs: devMs))
                        .frame(width: 16, height: 16)
                        .shadow(color: color(forMs: devMs).opacity(0.6), radius: 4)
                        .position(x: x, y: h / 2)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: viewModel.hits.count)
                }
            }
        }
        .frame(height: 44)
    }

    // MARK: - Scrolling timeline

    private var timeline: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                let now = CACurrentMediaTime()
                let window = 4.0
                let midY = size.height / 2
                let w = size.width
                let h = size.height

                func x(for t: Double) -> CGFloat {
                    w * CGFloat(1 - (now - t) / window)
                }

                // center line = perfect timing
                var center = Path()
                center.move(to: CGPoint(x: 0, y: midY))
                center.addLine(to: CGPoint(x: w, y: midY))
                context.stroke(center, with: .color(.green.opacity(0.35)), lineWidth: 1)

                // beat gridlines
                if viewModel.isRunning && viewModel.secondsPerBeat > 0 {
                    let spb = viewModel.secondsPerBeat
                    let anchor = viewModel.anchor
                    var k = ((now - window - anchor) / spb).rounded(.down)
                    while true {
                        let t = anchor + k * spb
                        if t > now { break }
                        if t >= now - window {
                            let bx = x(for: t)
                            var line = Path()
                            line.move(to: CGPoint(x: bx, y: 6))
                            line.addLine(to: CGPoint(x: bx, y: h - 6))
                            context.stroke(line, with: .color(.white.opacity(0.10)), lineWidth: 1)
                        }
                        k += 1
                    }
                }

                // hits
                for hit in viewModel.hits {
                    guard hit.time >= now - window else { continue }
                    let hx = x(for: hit.time)
                    let devMs = hit.deviation * 1000
                    let clamped = max(-maxDevMs, min(maxDevMs, devMs))
                    let hy = midY + CGFloat(clamped / maxDevMs) * (midY - 8)
                    let age = (now - hit.time) / window
                    let opacity = max(0.15, 1 - age)
                    let rect = CGRect(x: hx - 4, y: hy - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(color(forMs: devMs).opacity(opacity)))
                }

                // "now" marker at right edge
                var nowLine = Path()
                nowLine.move(to: CGPoint(x: w - 1, y: 0))
                nowLine.addLine(to: CGPoint(x: w - 1, y: h))
                context.stroke(nowLine, with: .color(.white.opacity(0.25)), lineWidth: 1)
            }
        }
        .frame(height: 130)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topLeading) {
            HStack {
                Text("late").font(.system(size: 9)).foregroundColor(.gray.opacity(0.5))
                Spacer()
            }
            .padding(6)
        }
        .overlay(alignment: .bottomLeading) {
            Text("early").font(.system(size: 9)).foregroundColor(.gray.opacity(0.5)).padding(6)
        }
    }

    // MARK: - Stats

    private var stats: some View {
        HStack(spacing: 12) {
            statCard(title: "Avg off", value: viewModel.hits.isEmpty ? "–" : String(format: "%.0f ms", viewModel.avgAbsMs))
            statCard(title: "In time", value: viewModel.hits.isEmpty ? "–" : String(format: "%.0f%%", viewModel.tightPercent))
            statCard(title: "Hits", value: "\(viewModel.hits.count)")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Calibration

    private var calibration: some View {
        VStack(spacing: 4) {
            HStack {
                Text(String(format: "Latency offset: %+.0f ms", viewModel.latencyOffsetMs))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
                Button("Reset") { viewModel.latencyOffsetMs = 0 }
                    .font(.system(size: 12))
                    .foregroundColor(.appAccent)
            }
            Slider(value: $viewModel.latencyOffsetMs, in: -80...80, step: 1)
                .tint(.gray)
        }
    }

    // MARK: - Start / Stop

    private var startStopButton: some View {
        Button {
            if viewModel.isRunning { viewModel.stop() } else { viewModel.start() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isRunning ? "stop.fill" : "play.fill")
                Text(viewModel.isRunning ? "Stop" : "Start")
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(viewModel.isRunning ? Color.red.opacity(0.85) : Color.green.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.bottom, 20)
    }

    // MARK: - Helpers

    private func color(forMs ms: Double) -> Color {
        let a = abs(ms)
        if a <= 30 { return .green }
        if a <= 55 { return .yellow }
        return .orange
    }
}
