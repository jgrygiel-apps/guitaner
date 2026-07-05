import SwiftUI

struct TuningPickerView: View {
    @Binding var selected: TuningDefinition
    let tunings: [TuningDefinition]

    @EnvironmentObject private var store: ProStore
    @State private var showPaywall = false

    /// Only Standard tuning is free; alternate tunings require Pro.
    private func isLocked(_ tuning: TuningDefinition) -> Bool {
        !store.hasAccess(to: .alternateTunings) && tuning.id != TuningDefinition.standard.id
    }

    var body: some View {
        Menu {
            ForEach(tunings) { tuning in
                Button {
                    if isLocked(tuning) {
                        showPaywall = true
                    } else {
                        selected = tuning
                    }
                } label: {
                    HStack {
                        Text(tuning.name)
                        if isLocked(tuning) {
                            Image(systemName: "lock.fill")
                        } else if tuning == selected {
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
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(store)
        }
    }
}
