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
                accent.opacity(colorScheme == .dark ? 0.16 : 0.12),
                accent.opacity(colorScheme == .dark ? 0.05 : 0.03),
                accent.opacity(colorScheme == .dark ? 0.16 : 0.12)
            ],
            center: .center
        )
    }

    private var activeRingOpacity: Double {
        let base = colorScheme == .dark ? 0.58 : 0.54
        let gain = colorScheme == .dark ? 0.24 : 0.22
        return min(0.84, base + gain * clampedProgress)
    }

    private var activeShadowOpacity: Double {
        let base = colorScheme == .dark ? 0.10 : 0.08
        let gain = colorScheme == .dark ? 0.10 : 0.08
        return min(0.22, base + gain * clampedProgress)
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
                .opacity(activeRingOpacity)
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: clampedProgress)
                .shadow(color: accent.opacity(activeShadowOpacity), radius: 6, x: 0, y: 2)

            Circle()
                .fill(
                    accent.opacity(colorScheme == .dark ? 0.12 : 0.08)
                )
                .padding(lineWidth + 10)

            VStack(spacing: 4) {
                if let unit = valueUnit, valueLines.count == 2 {
                    Text(valueLines[0])
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)

                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(valueLines[1])
                            .font(.title2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(unit)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(valueText)
                        .font(.title2.weight(.semibold))
                        .minimumScaleFactor(0.75)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }

                Text(caption)
                    .font(.footnote)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
        }
    }
}
