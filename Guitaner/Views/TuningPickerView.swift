import SwiftUI

struct TuningPickerView: View {
    @Binding var selected: TuningDefinition
    let tunings: [TuningDefinition]

    var body: some View {
        Menu {
            ForEach(tunings) { tuning in
                Button {
                    selected = tuning
                } label: {
                    HStack {
                        Text(tuning.name)
                        if tuning == selected {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selected.name)
                    .font(.system(size: 16, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}
