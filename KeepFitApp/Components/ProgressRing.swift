import SwiftUI

struct ProgressRing: View {
    @Environment(\.colorScheme) private var colorScheme

    let progress: Double
    let lineWidth: CGFloat
    let gradient: LinearGradient
    let accent: Color
    let valueText: String
    let caption: String

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color(.systemGray5), Color(.systemGray4)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: lineWidth
                )

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: clampedProgress)
                .shadow(color: accent.opacity(0.24), radius: 6, x: 0, y: 3)

            Circle()
                .fill(
                    colorScheme == .dark
                        ? Color.white.opacity(0.06)
                        : Color.white.opacity(0.55)
                )
                .overlay(
                    Circle()
                        .fill(accent.opacity(colorScheme == .dark ? 0.20 : 0.10))
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(colorScheme == .dark ? 0.18 : 0.44), lineWidth: 1)
                )
                .padding(lineWidth + 10)

            VStack(spacing: 4) {
                Text(valueText)
                    .font(.title3.weight(.semibold))
                    .minimumScaleFactor(0.75)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(caption)
                    .font(.caption2)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
        }
    }
}
