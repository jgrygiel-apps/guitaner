import SwiftUI

struct ChordLibraryView: View {
    @State private var selectedRoot: Int = 0        // 0=C, 1=C#, ..., 11=B
    @State private var selectedQualityIndex: Int = 0
    @State private var player = ChordPlayer()

    private let roots = ChordFingeringDatabase.rootNames
    private let qualities = ChordFingeringDatabase.qualities

    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    private var qualitySuffix: String {
        qualities[selectedQualityIndex].suffix
    }

    private var chordName: String {
        "\(roots[selectedRoot])\(qualitySuffix)"
    }

    private var fingerings: [ChordFingering] {
        ChordFingeringDatabase.fingerings(root: selectedRoot, quality: qualitySuffix)
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Root note picker
                rootPicker
                    .padding(.top, 12)

                // Quality picker
                qualityPicker
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                // Chord name
                Text(chordName)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 20)

                // Variants
                if fingerings.isEmpty {
                    Spacer()
                    Text("No fingerings available")
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: gridColumns, spacing: 16) {
                            ForEach(fingerings) { variant in
                                variantCard(variant)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .onDisappear {
            player.stop()
        }
    }

    private func playChord(_ fingering: ChordFingering) {
        player.stop()
        player.play(chords: [fingering.frequencies])
    }

    // MARK: - Root Picker

    private var rootPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<12, id: \.self) { index in
                    Button {
                        selectedRoot = index
                    } label: {
                        Text(roots[index])
                            .font(.system(size: 15, weight: selectedRoot == index ? .bold : .medium))
                            .foregroundColor(selectedRoot == index ? .white : .gray)
                            .frame(minWidth: 36, minHeight: 36)
                            .background(selectedRoot == index ? Color.appAccent : Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Quality Picker

    private var qualityPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(qualities.enumerated()), id: \.offset) { index, quality in
                    Button {
                        selectedQualityIndex = index
                    } label: {
                        Text(quality.name)
                            .font(.system(size: 13, weight: selectedQualityIndex == index ? .semibold : .regular))
                            .foregroundColor(selectedQualityIndex == index ? .white : .gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selectedQualityIndex == index ? Color.appAccent.opacity(0.8) : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Variant Card

    private func variantCard(_ fingering: ChordFingering) -> some View {
        VStack(spacing: 8) {
            Text(fingering.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)

            FretboardView(fingering: fingering)
                .frame(height: 200)
                .frame(maxWidth: .infinity)

            // String notes
            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { i in
                    let fret = fingering.strings[i]
                    Text(fret == -1 ? "×" : fret == 0 ? "○" : "\(fret)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(fret == -1 ? .red.opacity(0.5) : .gray.opacity(0.6))
                        .frame(width: 30)
                }
            }

            // Play button
            Button {
                playChord(fingering)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "play.fill")
                    Text("Play")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.8))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
