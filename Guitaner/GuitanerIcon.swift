//
//  GuitanerIcon.swift
//  Guitaner
//
//  Resolution-independent tuning-meter mark. Renders crisply at any size —
//  use it in the app, and for the App Store export render it at 1024×1024.
//

import SwiftUI

// MARK: - Palette

private enum GTColor {
    static let bgTop     = Color(red: 0.239, green: 0.173, blue: 0.075) // #3d2c13
    static let bgMid     = Color(red: 0.129, green: 0.086, blue: 0.027) // #211607
    static let bgBottom  = Color(red: 0.071, green: 0.043, blue: 0.016) // #120b04

    static let amber     = Color(red: 0.878, green: 0.643, blue: 0.306) // #e0a44e
    static let amberLite = Color(red: 1.0,   green: 0.941, blue: 0.812) // #fff0cf
    static let amberDeep = Color(red: 0.788, green: 0.541, blue: 0.184) // #c98a2f

    static let cream     = Color(red: 0.957, green: 0.918, blue: 0.851) // #f4ead9
    static let green     = Color(red: 0.369, green: 0.788, blue: 0.541) // #5ec98a
    static let greenLite = Color(red: 0.494, green: 0.878, blue: 0.643) // #7ee0a4
}

// Pivot as a fraction of the canvas (horizontally centered, 76% down).
private let gtPivot = UnitPoint(x: 0.5, y: 0.76)

// MARK: - Tick model

private struct Tick: Identifiable {
    let id = UUID()
    let angle: Double      // degrees, 0 = straight up
    let width: CGFloat     // fraction of size
    let length: CGFloat    // fraction of size
    let color: Color
    let glow: CGFloat
}

private let gtTicks: [Tick] = [
    .init(angle: -78, width: 0.0094, length: 0.130, color: GTColor.amber.opacity(0.45), glow: 0),
    .init(angle: -52, width: 0.0094, length: 0.130, color: GTColor.amber.opacity(0.55), glow: 0),
    .init(angle: -26, width: 0.0125, length: 0.160, color: GTColor.green,               glow: 6),
    .init(angle:   0, width: 0.0125, length: 0.180, color: GTColor.greenLite,           glow: 9),
    .init(angle:  26, width: 0.0125, length: 0.160, color: GTColor.green,               glow: 6),
    .init(angle:  52, width: 0.0094, length: 0.130, color: GTColor.amber.opacity(0.55), glow: 0),
    .init(angle:  78, width: 0.0094, length: 0.130, color: GTColor.amber.opacity(0.45), glow: 0),
]

// MARK: - Icon

struct GuitanerIcon: View {
    /// Needle angle in degrees (0 = perfectly in tune). Drive this from your tuner.
    var needleAngle: Double = 0

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let pivot = CGPoint(x: s * gtPivot.x, y: s * gtPivot.y)
            let ringR = s * 0.35

            ZStack {
                // Background
                RadialGradient(
                    colors: [GTColor.bgTop, GTColor.bgMid, GTColor.bgBottom],
                    center: UnitPoint(x: 0.5, y: 1.18),
                    startRadius: 0,
                    endRadius: s * 1.25
                )

                // Arc ring
                Path { p in
                    p.addArc(center: pivot, radius: ringR,
                             startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                }
                .stroke(GTColor.amber.opacity(0.16), lineWidth: s * 0.0063)

                // Ticks — each is drawn straight up, then rotated about the pivot.
                ForEach(gtTicks) { tick in
                    Capsule()
                        .fill(tick.color)
                        .frame(width: s * tick.width, height: s * tick.length)
                        .shadow(color: tick.glow > 0 ? GTColor.green.opacity(0.8) : .clear,
                                radius: tick.glow)
                        .position(x: pivot.x, y: pivot.y - ringR * 1.07 + s * tick.length / 2)
                        .frame(width: s, height: s)
                        .rotationEffect(.degrees(tick.angle), anchor: gtPivot)
                }

                // Note letter
                Text("E")
                    .font(.system(size: s * 0.20, weight: .bold))
                    .foregroundStyle(GTColor.cream)
                    .position(x: s * 0.5, y: s * 0.33)

                // Needle — vertical, rotated about the pivot.
                Capsule()
                    .fill(LinearGradient(colors: [GTColor.amberLite, GTColor.amber],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.019, height: s * 0.325)
                    .shadow(color: GTColor.amber.opacity(0.65), radius: s * 0.02)
                    .position(x: pivot.x, y: pivot.y - s * 0.1625)
                    .frame(width: s, height: s)
                    .rotationEffect(.degrees(needleAngle), anchor: gtPivot)

                // Pivot cap
                Circle()
                    .fill(RadialGradient(colors: [GTColor.amberLite, GTColor.amberDeep],
                                         center: UnitPoint(x: 0.35, y: 0.30),
                                         startRadius: 0, endRadius: s * 0.05))
                    .frame(width: s * 0.094, height: s * 0.094)
                    .overlay(Circle().stroke(GTColor.bgBottom.opacity(0.4), lineWidth: s * 0.019))
                    .shadow(color: GTColor.amber.opacity(0.7), radius: s * 0.022)
                    .position(pivot)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Rounded app-icon wrapper (for previews/mockups)

struct GuitanerAppIcon: View {
    var size: CGFloat = 180
    var body: some View {
        GuitanerIcon()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 32) {
        GuitanerAppIcon(size: 220)
        HStack(spacing: 20) {
            GuitanerAppIcon(size: 120)
            GuitanerAppIcon(size: 80)
            GuitanerAppIcon(size: 60)
        }
    }
    .padding(40)
    .background(Color.black)
}
