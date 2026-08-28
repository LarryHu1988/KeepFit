import SwiftUI

struct CardContainer<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let subtitle: String?
    let accent: Color
    @ViewBuilder var content: Content

    private var isCompactLayout: Bool {
        UIScreen.main.bounds.width <= 390 || dynamicTypeSize >= .xxxLarge
    }

    private var contentPadding: CGFloat {
        isCompactLayout ? 14 : 18
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .padding(.leading, 4)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.16), accent.opacity(0.07), .white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.42), lineWidth: 1)
                    )
                    .shadow(color: accent.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KeepFitFluidActionButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let systemImage: String
    let accent: Color
    let size: CGFloat
    let iconSize: CGFloat
    let feedbackToken: Int
    let action: () -> Void

    @State private var showsSuccess = false
    @State private var feedbackTask: Task<Void, Never>?

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: action) {
                    buttonLabel
                        .glassEffect(.regular.tint(accent).interactive(), in: .circle)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: action) {
                    buttonLabel
                        .background(legacySurface)
                }
                .buttonStyle(KeepFitFluidPressButtonStyle(accent: accent))
            }
        }
        .contentShape(Circle())
        .onChange(of: feedbackToken) { _, _ in
            showSuccessFeedback()
        }
        .onDisappear {
            feedbackTask?.cancel()
        }
    }

    private var buttonLabel: some View {
        Image(systemName: showsSuccess ? "checkmark" : systemImage)
            .font(.system(size: iconSize, weight: .bold))
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: feedbackToken)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var legacySurface: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [accent.opacity(0.98), accent.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.3), radius: 8, x: 0, y: 5)
    }

    private func showSuccessFeedback() {
        feedbackTask?.cancel()
        if reduceMotion {
            showsSuccess = true
        } else {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.62)) {
                showsSuccess = true
            }
        }

        feedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            if reduceMotion {
                showsSuccess = false
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                    showsSuccess = false
                }
            }
        }
    }
}

private struct KeepFitFluidPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Circle()
                    .fill(accent.opacity(configuration.isPressed ? 0.28 : 0))
                    .scaleEffect(configuration.isPressed ? 1.28 : 0.72)
                    .blur(radius: configuration.isPressed ? 5 : 1)
            }
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .rotationEffect(.degrees(configuration.isPressed && !reduceMotion ? -1.4 : 0))
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.27, dampingFraction: 0.56),
                value: configuration.isPressed
            )
    }
}

private struct KeepFitEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    let trigger: Int

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 14)
            .scaleEffect(isVisible ? 1 : 0.985, anchor: .top)
            .onAppear(perform: reveal)
            .onChange(of: trigger) { _, _ in
                reveal()
            }
    }

    private func reveal() {
        guard !KeepFitScreenshotConfig.isEnabled, !reduceMotion else {
            isVisible = true
            return
        }

        isVisible = false
        let delay = min(Double(index) * 0.035, 0.18)
        withAnimation(.spring(response: 0.48, dampingFraction: 0.84).delay(delay)) {
            isVisible = true
        }
    }
}

extension View {
    func keepFitEntrance(index: Int, trigger: Int) -> some View {
        modifier(KeepFitEntranceModifier(index: index, trigger: trigger))
    }
}
