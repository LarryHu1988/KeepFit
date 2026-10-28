import SwiftUI

struct GrowPageBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let accent: Color

    var body: some View {
        let isDark = colorScheme == .dark

        ZStack {
            LinearGradient(
                colors: isDark
                    ? [Color(red: 0.10, green: 0.12, blue: 0.15), Color(red: 0.06, green: 0.08, blue: 0.10)]
                    : [Color(red: 1.0, green: 0.98, blue: 0.94), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accent.opacity(isDark ? 0.24 : 0.20))
                .frame(width: 260, height: 260)
                .blur(radius: 16)
                .offset(x: 120, y: -280)

            Circle()
                .fill((isDark ? Color.white : Color.yellow).opacity(isDark ? 0.08 : 0.16))
                .frame(width: 220, height: 220)
                .blur(radius: 12)
                .offset(x: -150, y: -220)

            RoundedRectangle(cornerRadius: 110, style: .continuous)
                .fill((isDark ? Color.white : Color.white).opacity(isDark ? 0.07 : 0.24))
                .frame(width: 300, height: 120)
                .rotationEffect(.degrees(-12))
                .offset(x: 120, y: 360)
        }
        .ignoresSafeArea()
    }
}
