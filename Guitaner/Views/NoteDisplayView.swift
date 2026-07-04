import SwiftUI

struct NoteDisplayView: View {
    let note: String
    let octave: Int
    let isInTune: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(note)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(noteColor)

            if note != "--" {
                Text("\(octave)")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(noteColor.opacity(0.7))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: note)
        .animation(.easeInOut(duration: 0.15), value: isInTune)
    }

    private var noteColor: Color {
        if note == "--" { return .gray }
        return isInTune ? .green : .white
    }
}
