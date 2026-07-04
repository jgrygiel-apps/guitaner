import SwiftUI

struct StringIndicatorView: View {
    let tuning: TuningDefinition
    let activeIndex: Int?
    let isInTune: Bool
    let isManualMode: Bool
    let playingIndex: Int?
    var onStringTap: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(tuning.strings.enumerated()), id: \.offset) { index, note in
                StringDot(
                    label: note.name,
                    isActive: activeIndex == index,
                    isInTune: activeIndex == index && isInTune,
                    isPlaying: playingIndex == index,
                    isManualMode: isManualMode
                )
                .onTapGesture {
                    onStringTap?(index)
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

private struct StringDot: View {
    let label: String
    let isActive: Bool
    let isInTune: Bool
    let isPlaying: Bool
    let isManualMode: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 48, height: 48)

            if isActive || isPlaying {
                Circle()
                    .stroke(borderColor, lineWidth: 2)
                    .frame(width: 48, height: 48)
            }

            if isPlaying {
                // Pulsing ring for playing tone
                Circle()
                    .stroke(Color.appAccent.opacity(0.4), lineWidth: 2)
                    .frame(width: 48, height: 48)
                    .scaleEffect(1.3)
                    .opacity(0.5)
            }

            Text(label)
                .font(.system(size: 16, weight: isActive || isPlaying ? .bold : .medium, design: .rounded))
                .foregroundColor(textColor)
        }
        .animation(.easeInOut(duration: 0.15), value: isActive)
        .animation(.easeInOut(duration: 0.15), value: isInTune)
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
    }

    private var backgroundColor: Color {
        if isPlaying { return .appAccent.opacity(0.25) }
        if isInTune { return .green.opacity(0.2) }
        if isActive { return .white.opacity(0.15) }
        if isManualMode { return .white.opacity(0.08) }
        return .white.opacity(0.05)
    }

    private var borderColor: Color {
        if isPlaying { return .appAccent }
        if isInTune { return .green }
        return .white.opacity(0.5)
    }

    private var textColor: Color {
        if isPlaying { return .appAccent }
        if isInTune { return .green }
        if isActive { return .white }
        return .gray
    }
}
