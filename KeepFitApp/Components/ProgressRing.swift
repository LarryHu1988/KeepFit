import SwiftUI

struct ProgressRing: View {
    @Environment(\.colorScheme) private var colorScheme

    let progress: Double
    let lineWidth: CGFloat
    let gradient: LinearGradient
    let accent: Color
    let valueText: String
    let valueUnit: String?
    let caption: String

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var trackGradient: AngularGradient {
        AngularGradient(
            colors: [
                accent.opacity(colorScheme == .dark ? 0.24 : 0.18),
                accent.opacity(colorScheme == .dark ? 0.12 : 0.08),
                accent.opacity(colorScheme == .dark ? 0.24 : 0.18)
            ],
            center: .center
        )
    }

    private var valueLines: [String] {
        valueText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackGradient, lineWidth: lineWidth)

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
                    accent.opacity(colorScheme == .dark ? 0.18 : 0.12)
                )
                .overlay(
                    Circle()
                        .stroke(accent.opacity(colorScheme == .dark ? 0.24 : 0.20), lineWidth: 1)
                )
                .padding(lineWidth + 10)

            VStack(spacing: 4) {
                if let unit = valueUnit, valueLines.count == 2 {
                    Text(valueLines[0])
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)

                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(valueLines[1])
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(unit)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(valueText)
                        .font(.title3.weight(.semibold))
                        .minimumScaleFactor(0.75)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }

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
