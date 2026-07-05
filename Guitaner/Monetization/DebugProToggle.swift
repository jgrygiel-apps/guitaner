#if DEBUG
import SwiftUI

/// A tiny floating pill (DEBUG builds only) that flips the Pro entitlement so you
/// can test both free and Pro states without a real purchase. Never ships to the
/// App Store — the whole file is behind `#if DEBUG`.
struct DebugProToggle: View {
    @EnvironmentObject private var store: ProStore

    var body: some View {
        Button {
            store.setPro(!store.isPro)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: store.isPro ? "crown.fill" : "crown")
                Text(store.isPro ? "PRO" : "FREE")
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(store.isPro ? .appBGBottom : .appCream)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(store.isPro ? Color.appAmber : Color.black.opacity(0.55))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.appAmber.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
#endif
