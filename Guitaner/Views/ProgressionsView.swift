import SwiftUI
import Observation

/// Persists user-created progressions across launches.
@Observable
final class ProgressionStore {
    private let key = "custom.progressions"
    var custom: [Progression] = []

    init() { load() }

    func add(_ p: Progression) {
        custom.append(p)
        save()
    }

    func remove(_ p: Progression) {
        custom.removeAll { $0.id == p.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([Progression].self, from: data) else { return }
        custom = arr
    }

    private func save() {
        if let data = try? JSONEncoder().encode(custom) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct ProgressionsView: View {
    @State private var store = ProgressionStore()
    @State private var player = ChordPlayer()
    @State private var selectedKey: Int = 0            // 0 = C
    @State private var selectedCategory: String = "Pop"
    @State private var selectedProgression: Progression?
    @State private var showBuilder = false
    @State private var isPlaying = false

    private let roots = ChordFingeringDatabase.rootNames

    private var categories: [String] {
        ProgressionLibrary.categories(including: store.custom)
    }

    private var visibleProgressions: [Progression] {
        if selectedCategory == "My Progressions" {
            return store.custom
        }
        return ProgressionLibrary.all.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                keyPicker
                    .padding(.top, 10)

                categoryChips
                    .padding(.top, 12)

                if let progression = selectedProgression {
                    chordStrip(progression)
                        .padding(.top, 12)
                }

                progressionList
                    .padding(.top, 8)
            }
        }
        .onAppear {
            if selectedProgression == nil {
                selectedProgression = visibleProgressions.first
            }
            player.onFinished = { isPlaying = false }
        }
        .onDisappear {
            player.stop()
        }
        .sheet(isPresented: $showBuilder) {
            ProgressionBuilderView(keyRoot: selectedKey) { newProgression in
                store.add(newProgression)
                selectedCategory = "My Progressions"
                selectedProgression = newProgression
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Progressions")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Button {
                showBuilder = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Build")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.appAccent)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Key Picker

    private var keyPicker: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Key")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<12, id: \.self) { index in
                        Button {
                            selectedKey = index
                        } label: {
                            Text(roots[index])
                                .font(.system(size: 14, weight: selectedKey == index ? .bold : .medium))
                                .foregroundColor(selectedKey == index ? .white : .gray)
                                .frame(minWidth: 34, minHeight: 34)
                                .background(selectedKey == index ? Color.appAccent : Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                        selectedProgression = visibleProgressions.first
                    } label: {
                        Text(category)
                            .font(.system(size: 13, weight: selectedCategory == category ? .semibold : .regular))
                            .foregroundColor(selectedCategory == category ? .white : .gray)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedCategory == category ? Color.appAccent.opacity(0.8) : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Chord Strip (selected progression rendered as diagrams)

    private func chordStrip(_ progression: Progression) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(progression.numeralSummary)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    if isPlaying {
                        player.stop()
                        isPlaying = false
                    } else {
                        play(progression)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        Text(isPlaying ? "Stop" : "Play")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(isPlaying ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(progression.steps) { step in
                        chordCard(step)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
    }

    private func chordCard(_ step: ProgressionStep) -> some View {
        VStack(spacing: 4) {
            Text(step.numeral)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appAccent.opacity(0.8))
            Text(step.chordName(inKey: selectedKey))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if let fingering = step.fingering(inKey: selectedKey) {
                FretboardView(fingering: fingering)
                    .frame(width: 118, height: 150)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 118, height: 150)
                    .overlay(Text("—").foregroundColor(.gray))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Progression List

    private var progressionList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                if visibleProgressions.isEmpty {
                    Text("No progressions yet. Tap “Build” to create one.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.top, 40)
                }

                ForEach(visibleProgressions) { progression in
                    Button {
                        selectedProgression = progression
                        play(progression)
                    } label: {
                        progressionRow(progression)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Playback

    private func play(_ progression: Progression) {
        player.stop()
        let chords = progression.steps.map { $0.frequencies(inKey: selectedKey) }
        player.play(chords: chords)
        isPlaying = true
    }

    private func progressionRow(_ progression: Progression) -> some View {
        let isSelected = selectedProgression?.id == progression.id
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(progression.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(progression.numeralSummary)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer()
            if progression.isCustom {
                Button {
                    store.remove(progression)
                    if selectedProgression?.id == progression.id {
                        selectedProgression = visibleProgressions.first { $0.id != progression.id }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(isSelected ? Color.appAccent.opacity(0.18) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.appAccent.opacity(0.6) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Custom Progression Builder

private struct ProgressionBuilderView: View {
    let keyRoot: Int
    let onSave: (Progression) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var steps: [ProgressionStep] = []

    private let roots = ChordFingeringDatabase.rootNames

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 16) {
                    TextField("Progression name", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    // Current steps
                    if steps.isEmpty {
                        Text("Tap degrees below to add chords (key of \(roots[keyRoot]))")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                    VStack(spacing: 2) {
                                        Text(step.numeral)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.appAccent.opacity(0.8))
                                        Text(step.chordName(inKey: keyRoot))
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onTapGesture { steps.remove(at: index) }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    Divider().overlay(Color.white.opacity(0.1))

                    // Degree palette
                    Text("Add chord")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray.opacity(0.6))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(ProgressionLibrary.builderDegrees) { degree in
                            Button {
                                steps.append(ProgressionStep(semitone: degree.semitone,
                                                             quality: degree.quality,
                                                             numeral: degree.numeral))
                            } label: {
                                VStack(spacing: 1) {
                                    Text(degree.numeral)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(degree.chordName(inKey: keyRoot))
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationTitle("New Progression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let finalName = name.trimmingCharacters(in: .whitespaces)
                        let progression = Progression(
                            name: finalName.isEmpty ? "My Progression" : finalName,
                            category: "My Progressions",
                            steps: steps,
                            isCustom: true
                        )
                        onSave(progression)
                        dismiss()
                    }
                    .disabled(steps.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
