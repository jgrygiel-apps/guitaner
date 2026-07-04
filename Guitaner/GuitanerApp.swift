import SwiftUI

@main
struct GuitanerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Shows the animated splash on launch, then fades into the main tab bar.
private struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            mainTabs

            if showSplash {
                SplashScreen {
                    withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            TunerView()
                .tabItem {
                    Image(systemName: "tuningfork")
                    Text("Tuner")
                }

            if FeatureFlags.isEnabled(.chordDetection) {
                ChordView()
                    .tabItem {
                        Image(systemName: "guitars")
                        Text("Detect")
                    }
            }

            ProgressionsView()
                .tabItem {
                    Image(systemName: "music.note.list")
                    Text("Progressions")
                }

            PracticeView()
                .tabItem {
                    Image(systemName: "metronome")
                    Text("Practice")
                }

            ChordLibraryView()
                .tabItem {
                    Image(systemName: "book")
                    Text("Chords")
                }
        }
        .preferredColorScheme(.dark)
        .tint(.appAmber)
    }
}
