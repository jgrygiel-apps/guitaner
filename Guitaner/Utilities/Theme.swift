import SwiftUI

/// App palette, matched to the launch splash screen.
extension Color {
    static let appBGTop    = Color(red: 0.227, green: 0.165, blue: 0.071)  // #3a2a12
    static let appBGMid    = Color(red: 0.129, green: 0.086, blue: 0.027)  // #211607
    static let appBGBottom = Color(red: 0.071, green: 0.043, blue: 0.016)  // #120b04

    static let appAmber    = Color(red: 0.878, green: 0.643, blue: 0.306)  // bright amber — text/accents
    static let appAccent   = Color(red: 0.804, green: 0.545, blue: 0.196)  // deep amber — fills
    static let appCream    = Color(red: 0.961, green: 0.918, blue: 0.851)  // warm off-white
}

/// The splash screen's warm radial gradient, reused as the app-wide background.
struct AppBackground: View {
    var body: some View {
        GeometryReader { geo in
            RadialGradient(
                colors: [.appBGTop, .appBGMid, .appBGBottom],
                center: UnitPoint(x: 0.5, y: 0.30),
                startRadius: 0,
                endRadius: max(geo.size.width, geo.size.height) * 0.95
            )
        }
        .ignoresSafeArea()
    }
}
