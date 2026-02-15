import SwiftUI

struct CardContainer<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let accent: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                SymbolBadge(symbol: icon, tint: accent, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white, accent.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.95), lineWidth: 1)

                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .offset(x: 130, y: -70)
                        .blur(radius: 2)
                }
                .shadow(color: accent.opacity(0.16), radius: 16, x: 0, y: 8)
            )
        }
    }
}
