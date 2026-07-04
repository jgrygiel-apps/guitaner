import SwiftUI

/// Renders a guitar chord diagram on a 6-string fretboard.
struct FretboardView: View {
    let fingering: ChordFingering

    private let stringNames = ["E", "A", "D", "G", "B", "E"]
    private let visibleFrets = 5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let leftPadding: CGFloat = 30
            let topPadding: CGFloat = 30
            let bottomPadding: CGFloat = 16
            let rightPadding: CGFloat = 16

            let gridWidth = w - leftPadding - rightPadding
            let gridHeight = h - topPadding - bottomPadding
            let stringSpacing = gridWidth / 5
            let fretSpacing = gridHeight / CGFloat(visibleFrets)

            let startFret = displayStartFret

            ZStack(alignment: .topLeading) {
                // Fret number label
                if startFret > 1 {
                    Text("\(startFret)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                        .position(x: leftPadding - 16, y: topPadding + fretSpacing / 2)
                }

                // Nut (thick bar at top for open position)
                if startFret <= 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: gridWidth + 2, height: 4)
                        .position(x: leftPadding + gridWidth / 2, y: topPadding)
                }

                // Fret lines (horizontal)
                ForEach(0...visibleFrets, id: \.self) { fret in
                    let y = topPadding + CGFloat(fret) * fretSpacing
                    Path { path in
                        path.move(to: CGPoint(x: leftPadding, y: y))
                        path.addLine(to: CGPoint(x: leftPadding + gridWidth, y: y))
                    }
                    .stroke(Color.gray.opacity(fret == 0 && startFret <= 1 ? 0 : 0.4), lineWidth: 1)
                }

                // String lines (vertical)
                ForEach(0..<6, id: \.self) { string in
                    let x = leftPadding + CGFloat(string) * stringSpacing
                    Path { path in
                        path.move(to: CGPoint(x: x, y: topPadding))
                        path.addLine(to: CGPoint(x: x, y: topPadding + gridHeight))
                    }
                    .stroke(Color.gray.opacity(0.5), lineWidth: string == 0 || string == 5 ? 1.5 : 1)
                }

                // Fret dots (position markers)
                let dotFrets = [3, 5, 7, 9, 12, 15]
                ForEach(dotFrets, id: \.self) { fretNum in
                    let relativeFret = fretNum - startFret + 1
                    if relativeFret >= 1 && relativeFret <= visibleFrets {
                        let y = topPadding + (CGFloat(relativeFret) - 0.5) * fretSpacing
                        if fretNum == 12 {
                            // Double dot
                            ForEach([1.5, 3.5], id: \.self) { pos in
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 6, height: 6)
                                    .position(x: leftPadding + CGFloat(pos) * stringSpacing, y: y)
                            }
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 6, height: 6)
                                .position(x: leftPadding + 2.5 * stringSpacing, y: y)
                        }
                    }
                }

                // Barre bar
                if let barre = fingering.barreString {
                    let relativeFret = barre - startFret + 1
                    if relativeFret >= 1 && relativeFret <= visibleFrets {
                        let y = topPadding + (CGFloat(relativeFret) - 0.5) * fretSpacing
                        // Find which strings are barred (all strings at barre fret)
                        let barreStrings = fingering.strings.enumerated().filter { $0.element >= barre }
                        if let firstIdx = barreStrings.first?.offset,
                           let lastIdx = barreStrings.last?.offset {
                            let x1 = leftPadding + CGFloat(firstIdx) * stringSpacing
                            let x2 = leftPadding + CGFloat(lastIdx) * stringSpacing
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.9))
                                .frame(width: x2 - x1 + 14, height: 12)
                                .position(x: (x1 + x2) / 2, y: y)
                        }
                    }
                }

                // Finger dots and markers
                ForEach(0..<6, id: \.self) { string in
                    let fretValue = fingering.strings[string]
                    let x = leftPadding + CGFloat(string) * stringSpacing

                    if fretValue == -1 {
                        // Muted string: X above nut
                        Text("×")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red.opacity(0.7))
                            .position(x: x, y: topPadding - 14)
                    } else if fretValue == 0 {
                        // Open string: O above nut
                        Circle()
                            .stroke(Color.green.opacity(0.7), lineWidth: 1.5)
                            .frame(width: 12, height: 12)
                            .position(x: x, y: topPadding - 14)
                    } else {
                        // Fretted note: filled circle
                        let relativeFret = fretValue - startFret + 1
                        if relativeFret >= 1 && relativeFret <= visibleFrets {
                            let y = topPadding + (CGFloat(relativeFret) - 0.5) * fretSpacing

                            // Skip drawing dot if covered by barre
                            if fingering.barreString == nil || fretValue != fingering.barreString {
                                ZStack {
                                    Circle()
                                        .fill(Color.appAccent)
                                        .frame(width: 22, height: 22)

                                    let finger = fingering.fingers[string]
                                    if finger > 0 {
                                        Text("\(finger)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .position(x: x, y: y)
                            }
                        }
                    }
                }

                // String labels at bottom
                ForEach(0..<6, id: \.self) { string in
                    let x = leftPadding + CGFloat(string) * stringSpacing
                    Text(stringNames[string])
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray.opacity(0.5))
                        .position(x: x, y: topPadding + gridHeight + 10)
                }
            }
        }
    }

    /// Determine the starting fret for the display window.
    private var displayStartFret: Int {
        let frettedNotes = fingering.strings.filter { $0 > 0 }
        guard let minFret = frettedNotes.min() else { return 1 }

        if minFret <= visibleFrets && fingering.baseFret <= 1 {
            return 1 // open position
        }
        return max(1, minFret)
    }
}
