//
//  SplashScreen.swift
//  Guitaner
//
//  Animated launch screen: the tuning needle swings in and settles onto the
//  green "in tune" mark, then the wordmark rises. Call `onFinished` to route
//  into your root view.
//

import SwiftUI

struct SplashScreen: View {
    var onFinished: () -> Void = {}

    @State private var needleAngle: Double = -16
    @State private var glow = false
    @State private var wordmarkIn = false
    @State private var loaderPhase: CGFloat = -1

    // Match the icon palette.
    private let bgTop    = Color(red: 0.227, green: 0.165, blue: 0.071)
    private let bgMid    = Color(red: 0.129, green: 0.086, blue: 0.027)
    private let bgBottom = Color(red: 0.071, green: 0.043, blue: 0.016)
    private let amber    = Color(red: 0.878, green: 0.643, blue: 0.306)
    private let amberTxt = Color(red: 0.753, green: 0.541, blue: 0.271)
    private let cream    = Color(red: 0.961, green: 0.918, blue: 0.851)
    private let muted    = Color(red: 0.435, green: 0.384, blue: 0.314)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                RadialGradient(colors: [bgTop, bgMid, bgBottom],
                               center: UnitPoint(x: 0.5, y: 0.34),
                               startRadius: 0, endRadius: h * 0.9)
                    .ignoresSafeArea()

                // Ambient glow behind the mark
                Circle()
                    .fill(RadialGradient(colors: [amber.opacity(0.22), .clear],
                                         center: .center, startRadius: 0, endRadius: w * 0.42))
                    .frame(width: w * 0.86, height: w * 0.86)
                    .blur(radius: 6)
                    .opacity(glow ? 1 : 0.55)
                    .position(x: w * 0.5, y: h * 0.34)

                // The mark, needle driven by state
                GuitanerIcon(needleAngle: needleAngle)
                    .frame(width: w * 0.5, height: w * 0.5)
                    .clipShape(RoundedRectangle(cornerRadius: w * 0.5 * 0.2237, style: .continuous))
                    .position(x: w * 0.5, y: h * 0.34)

                // Wordmark
                VStack(spacing: 12) {
                    Text("Guitaner")
                        .font(.system(size: 42, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(cream)
                    Text("TUNE · CHORDS · PLAY")
                        .font(.system(size: 14, weight: .medium))
                        .tracking(4.5)
                        .foregroundStyle(amberTxt)
                }
                .opacity(wordmarkIn ? 1 : 0)
                .offset(y: wordmarkIn ? 0 : 14)
                .position(x: w * 0.5, y: h * 0.60)

                // Loading bar
                ZStack(alignment: .leading) {
                    Capsule().fill(amber.opacity(0.14))
                    Capsule()
                        .fill(LinearGradient(colors: [.clear, amber, .clear],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: 60)
                        .offset(x: loaderPhase * 150)
                }
                .frame(width: 150, height: 3)
                .position(x: w * 0.5, y: h - 132)

                // Footer
                Text("PERFECT PITCH, EVERY TIME")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(1.9)
                    .foregroundStyle(muted)
                    .position(x: w * 0.5, y: h - 54)
            }
        }
        .onAppear(perform: runAnimation)
    }

    private func runAnimation() {
        // Needle settles onto zero with a damped spring.
        withAnimation(.spring(response: 0.9, dampingFraction: 0.45)) {
            needleAngle = 0
        }
        // Glow pulse (loops).
        withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
            glow = true
        }
        // Wordmark rises shortly after.
        withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
            wordmarkIn = true
        }
        // Loader sweep (loops).
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
            loaderPhase = 1
        }
        // Hand off to the app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            onFinished()
        }
    }
}

#Preview {
    SplashScreen()
}
