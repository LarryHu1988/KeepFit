import SwiftUI

struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let gradient: LinearGradient
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
                .shadow(color: .orange.opacity(0.22), radius: 6, x: 0, y: 3)

            Circle()
                .fill(Color.white.opacity(0.8))
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
