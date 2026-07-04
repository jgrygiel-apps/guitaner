import SwiftUI

struct FrequencyDisplayView: View {
    let frequency: Float
    let cents: Float

    var body: some View {
        HStack(spacing: 24) {
            // Frequency readout
            VStack(spacing: 2) {
                Text(frequencyText)
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                Text("Hz")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
            }

            // Cents readout
            VStack(spacing: 2) {
                Text(centsText)
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundColor(centsColor)
                Text("cents")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
    }

    private var frequencyText: String {
        frequency > 0 ? String(format: "%.1f", frequency) : "---.-"
    }

    private var centsText: String {
        guard frequency > 0 else { return "---" }
        let sign = cents >= 0 ? "+" : ""
        return String(format: "%@%.1f", sign, cents)
    }

    private var centsColor: Color {
        guard frequency > 0 else { return .gray }
        let absCents = abs(cents)
        if absCents <= AudioConstants.inTuneToleranceCents { return .green }
        if absCents <= 10 { return .yellow }
        return .orange
    }
}
