import SwiftUI

struct PitchHistoryView: View {
    let history: [Float]   // cents deviation values, newest last
    let maxCents: Float
    let isInTune: Bool

    private let inTuneZone: Float = 5.0  // cents

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let midY = h / 2

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))

                // In-tune zone (green band around center)
                let zoneHeight = h * CGFloat(inTuneZone / maxCents)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green.opacity(0.08))
                    .frame(height: zoneHeight)
                    .position(x: w / 2, y: midY)

                // Center line (perfect pitch)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: w, y: midY))
                }
                .stroke(Color.green.opacity(0.3), lineWidth: 1)

                // Pitch history line
                if history.count >= 2 {
                    // Glow behind line
                    pitchPath(in: geo.size)
                        .stroke(lineColor.opacity(0.3), lineWidth: 4)
                        .blur(radius: 3)

                    // Main line
                    pitchPath(in: geo.size)
                        .stroke(
                            lineGradient,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )

                    // Current position dot
                    if let lastCents = history.last {
                        let y = midY - CGFloat(clamp(lastCents, maxCents)) * (midY / CGFloat(maxCents))
                        Circle()
                            .fill(dotColor(for: lastCents))
                            .frame(width: 8, height: 8)
                            .shadow(color: dotColor(for: lastCents).opacity(0.6), radius: 4)
                            .position(x: w, y: y)
                    }
                }

                // Scale labels
                VStack {
                    HStack {
                        Text("+\(Int(maxCents))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.5))
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Text("0")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.green.opacity(0.5))
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Text("-\(Int(maxCents))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.5))
                        Spacer()
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
        }
    }

    private func pitchPath(in size: CGSize) -> Path {
        let count = history.count
        guard count >= 2 else { return Path() }

        let midY = size.height / 2
        let stepX = size.width / CGFloat(max(count - 1, 1))

        return Path { path in
            for (i, cents) in history.enumerated() {
                let x = CGFloat(i) * stepX
                let clamped = clamp(cents, maxCents)
                let y = midY - CGFloat(clamped) * (midY / CGFloat(maxCents))

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    // Smooth curve using quadratic bezier
                    let prevCents = clamp(history[i - 1], maxCents)
                    let prevY = midY - CGFloat(prevCents) * (midY / CGFloat(maxCents))
                    let prevX = CGFloat(i - 1) * stepX
                    let controlX = (prevX + x) / 2
                    path.addQuadCurve(
                        to: CGPoint(x: x, y: y),
                        control: CGPoint(x: controlX, y: (prevY + y) / 2)
                    )
                }
            }
        }
    }

    private var lineColor: Color {
        guard let last = history.last else { return .gray }
        return dotColor(for: last)
    }

    private var lineGradient: LinearGradient {
        LinearGradient(
            colors: [lineColor.opacity(0.2), lineColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func dotColor(for cents: Float) -> Color {
        let absCents = abs(cents)
        if absCents <= inTuneZone { return .green }
        if absCents <= 15 { return .yellow }
        return .orange
    }

    private func clamp(_ value: Float, _ limit: Float) -> Float {
        max(-limit, min(limit, value))
    }
}
