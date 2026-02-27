import SwiftUI

// AndroidのLiquidSystem.ktにあるLiquidSlider / LiquidSectionHeader相当。

struct LiquidSectionHeader: View {
    let text: String
    @Environment(\.layoutMetrics) private var metrics

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: metrics.headerFontSize, weight: .semibold))
            .foregroundColor(.accentPrimary)
            .tracking(0.15)
            .padding(.bottom, metrics.headerBottomPad)
    }
}

struct LiquidSlider: View {
    @Binding var value: Float
    var enabled: Bool = true
    var range: ClosedRange<Float> = 0...1
    var onEditingChanged: ((Bool) -> Void)? = nil

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                .clamped01

            HStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.glassSurfaceDark)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.accentPrimary)
                        .frame(width: width * progress, height: 6)
                }
                .frame(height: 40)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            guard enabled else { return }
                            if !isDragging {
                                isDragging = true
                                onEditingChanged?(true)
                            }
                            let x = min(max(0, g.location.x), width)
                            let p = Float(x / width)
                            value = range.lowerBound + p * (range.upperBound - range.lowerBound)
                        }
                        .onEnded { _ in
                            guard enabled else { return }
                            isDragging = false
                            onEditingChanged?(false)
                        }
                )
                .opacity(enabled ? 1 : 0.55)
            }
        }
        .frame(height: 40)
    }
}

private extension CGFloat {
    var clamped01: CGFloat {
        Swift.min(Swift.max(self, 0), 1)
    }
}

// MARK: - LiquidButton
struct LiquidButton<Content: View>: View {
    let action: () -> Void
    var height: CGFloat
    let content: Content

    @State private var isPressed = false

    init(action: @escaping () -> Void, height: CGFloat = 56, @ViewBuilder content: () -> Content) {
        self.action = action
        self.height = height
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: height) // Android LiquidDimensions.ButtonHeight = 56.dp by default
                .background(
                    LinearGradient(
                        colors: [.accentStart, .accentEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(BouncyButtonStyle(scaleDownTo: 0.9, bounceTo: 1.05))
    }
}

// MARK: - LiquidRoundButton
struct LiquidRoundButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22))
                .foregroundColor(.white) // Using white since it's glass
                .frame(width: 42, height: 42)
                .background(Color.glassSurface)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.glassBorderAndroid, lineWidth: 1))
        }
        .buttonStyle(BouncyButtonStyle(scaleDownTo: 0.85, bounceTo: 1.0))
    }
}

// MARK: - LiquidChip
struct LiquidChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? Color(white: 0.05) : Color(white: 0.9)) // TextMediumEmphasis approximation
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentPrimary : Color.glassSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? Color.accentPrimary.opacity(0.8) : Color.glassBorderAndroid, lineWidth: 1)
                )
        }
        .buttonStyle(BouncyButtonStyle(scaleDownTo: 0.95, bounceTo: 1.02))
    }
}

// MARK: - Spring Button Style
private struct BouncyButtonStyle: ButtonStyle {
    let scaleDownTo: CGFloat
    let bounceTo: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleDownTo : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: configuration.isPressed)
    }
}

