import SwiftUI

struct GrowPageBackground: View {
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.98, blue: 0.94), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accent.opacity(0.20))
                .frame(width: 260, height: 260)
                .blur(radius: 16)
                .offset(x: 120, y: -280)

            Circle()
                .fill(Color.yellow.opacity(0.16))
                .frame(width: 220, height: 220)
                .blur(radius: 12)
                .offset(x: -150, y: -220)

            RoundedRectangle(cornerRadius: 110, style: .continuous)
                .fill(Color.white.opacity(0.24))
                .frame(width: 300, height: 120)
                .rotationEffect(.degrees(-12))
                .offset(x: 120, y: 360)
        }
        .ignoresSafeArea()
    }
}
