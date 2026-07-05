import SwiftUI

/// The upsell sheet. Lists everything Pro unlocks and drives `ProStore.purchase()`.
struct PaywallView: View {
    @EnvironmentObject private var store: ProStore
    @Environment(\.dismiss) private var dismiss
    @State private var working = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Image(systemName: "guitars.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.appAmber)
                        Text("Guitaner Pro")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.appCream)
                        Text("Unlock every tuning, chord and practice tool.")
                            .font(.system(size: 15))
                            .foregroundColor(.appAmber.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 14) {
                        ForEach(ProFeature.allCases) { feature in
                            HStack(spacing: 14) {
                                Image(systemName: feature.systemImage)
                                    .font(.system(size: 18))
                                    .foregroundColor(.appAmber)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feature.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.appCream)
                                    Text(feature.subtitle)
                                        .font(.system(size: 13))
                                        .foregroundColor(.appCream.opacity(0.65))
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(spacing: 10) {
                        Button {
                            Task { await buy() }
                        } label: {
                            Text(working ? "Please wait…" : "Unlock Pro")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.appBGBottom)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.appAmber)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(working)

                        Button("Restore Purchase") {
                            Task { await store.restore(); if store.isPro { dismiss() } }
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.appAmber)
                    }

                    // TODO: real price string from the store product, plus
                    // Terms of Use & Privacy Policy links (App Store requires them).
                    Text("Placeholder — real pricing comes from the App Store product.")
                        .font(.system(size: 11))
                        .foregroundColor(.appCream.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.appCream.opacity(0.4))
                    .padding(16)
            }
        }
    }

    private func buy() async {
        working = true
        await store.purchase()
        working = false
        if store.isPro { dismiss() }
    }
}

// MARK: - Full-screen lock

/// Replacement content shown when a whole screen (e.g. the Practice tab) is Pro-only.
struct ProLockedView: View {
    let feature: ProFeature
    @EnvironmentObject private var store: ProStore
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.appAmber)

                Text(feature.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.appCream)

                Text(feature.subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(.appCream.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    showPaywall = true
                } label: {
                    Text("Unlock Guitaner Pro")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appBGBottom)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 13)
                        .background(Color.appAmber)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(store)
        }
    }
}

// MARK: - Gating helper

/// Wraps content so that tapping it while locked presents the paywall instead of
/// running the action. Usage:
///
/// ```
/// Button("Save progression") { save() }
///     .proGate(.customProgressions)
/// ```
private struct ProGate: ViewModifier {
    let feature: ProFeature
    @EnvironmentObject private var store: ProStore
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        Group {
            if store.hasAccess(to: feature) {
                content
            } else {
                content
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.appAmber)
                            .padding(4)
                            .background(Color.appBGBottom.opacity(0.7), in: Circle()),
                        alignment: .topTrailing
                    )
                    // Intercept taps before the wrapped control sees them.
                    .allowsHitTesting(false)
                    .overlay(
                        Button { showPaywall = true } label: {
                            Color.clear.contentShape(Rectangle())
                        }
                    )
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(store)
        }
    }
}

extension View {
    /// Locks this view behind `feature`; tapping while locked shows the paywall.
    func proGate(_ feature: ProFeature) -> some View {
        modifier(ProGate(feature: feature))
    }
}
