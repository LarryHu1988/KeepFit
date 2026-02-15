import SwiftUI

struct AppIconBadge: View {
    let icon: String
    let seed: String
    let size: CGFloat

    var body: some View {
        Group {
            if icon.hasPrefix("sf:") {
                Image(systemName: String(icon.dropFirst(3)))
                    .font(.system(size: size * 0.62, weight: .semibold))
                    .foregroundStyle(.primary)
            } else {
                Text(icon)
                    .font(.system(size: size * 0.72))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
