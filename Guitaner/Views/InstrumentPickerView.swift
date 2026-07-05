import SwiftUI

/// Compact menu for choosing the chord-preview instrument. Reads and writes the
/// shared `InstrumentStore`, so every screen that plays chords stays in sync.
struct InstrumentPickerView: View {
    @EnvironmentObject private var store: InstrumentStore

    var body: some View {
        Menu {
            ForEach(Instrument.allCases) { instrument in
                Button {
                    store.selected = instrument
                } label: {
                    HStack {
                        Label(instrument.name, systemImage: instrument.systemImage)
                        if instrument == store.selected {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: store.selected.systemImage)
                    .font(.system(size: 13))
                Text(store.selected.name)
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}
